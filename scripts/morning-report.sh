#!/usr/bin/env bash
# Write one read-only Markdown status report. Every section degrades to an
# explicit "unknown" marker when its source is unavailable; the only non-zero
# exit is a report that could not be written. Nothing here mutates systemd,
# services, repositories, or data.
set -euo pipefail

: "${MORNING_REPORT_DIR:?MORNING_REPORT_DIR must be set}"
: "${MORNING_REPORT_REPO:?MORNING_REPORT_REPO must be set}"
: "${MORNING_REPORT_GITHUB_REPO:?MORNING_REPORT_GITHUB_REPO must be set}"
: "${HOMELAB_IMPORTANT_UNITS:?HOMELAB_IMPORTANT_UNITS must be set}"
: "${CLIPROXYAPI_READINESS_FILE:?CLIPROXYAPI_READINESS_FILE must be set}"

if (($# != 0)); then
  echo "morning-report accepts no arguments" >&2
  exit 2
fi

unknown="unknown"
command_timeout=60
today=$(date +%F)
report_file="$MORNING_REPORT_DIR/$today.md"

mkdir -p "$MORNING_REPORT_DIR"
report_tmp=$(mktemp "$report_file.XXXXXX")
scratch=$(mktemp -d)
cleanup() {
  rm -f "$report_tmp"
  rm -rf "$scratch"
}
trap cleanup EXIT

# Subprocesses run from an empty directory so tools that auto-load dotfiles
# from the working directory (Bun behind cliproxyapi-util, for example) find
# nothing to read. Repository access always goes through `git -C`.
cd "$scratch"

mark_unknown() {
  printf -- '- %s: %s\n' "$unknown" "$1"
}

# Turn stdin lines into Markdown bullets; print a fallback bullet when empty.
bullets_or() {
  local fallback=$1 line emitted=0
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    printf -- '- %s\n' "$line"
    emitted=1
  done
  ((emitted)) || printf -- '- %s\n' "$fallback"
}

# Print "unit<TAB>ActiveState<TAB>SubState<TAB>Type" per unit via one
# `systemctl show`, which tolerates units that are not loaded.
unit_states() {
  local scope=$1
  shift
  local -a scope_flag=()
  [[ $scope == user ]] && scope_flag=(--user)
  timeout "$command_timeout" systemctl "${scope_flag[@]}" show \
    --property=Id --property=ActiveState --property=SubState --property=Type -- "$@" 2>/dev/null |
    awk -F= '
      function flush() {
        if (unit != "") {
          printf "%s\t%s\t%s\t%s\n", unit, state, substate, kind
        }
        unit = ""; state = ""; substate = ""; kind = ""
      }
      $1 == "Id" { flush(); unit = substr($0, 4); next }
      $1 == "ActiveState" { state = substr($0, 13); next }
      $1 == "SubState" { substate = substr($0, 10); next }
      $1 == "Type" { kind = substr($0, 6); next }
      /^$/ { flush() }
      END { flush() }
    '
}

failed_units() {
  local scope=$1
  local -a scope_flag=()
  [[ $scope == user ]] && scope_flag=(--user)
  timeout "$command_timeout" systemctl "${scope_flag[@]}" --failed --no-legend --plain 2>/dev/null
}

section_systemd() {
  local output
  printf '## Failed or degraded systemd units\n\n'

  printf '### System units reported failed\n\n'
  if output=$(failed_units system); then
    printf '%s\n' "$output" | bullets_or "none"
  else
    mark_unknown "systemctl --failed did not answer"
  fi

  printf '\n### User units reported failed\n\n'
  if output=$(failed_units user); then
    printf '%s\n' "$output" | bullets_or "none"
  else
    mark_unknown "systemctl --user --failed did not answer"
  fi

  printf '\n### Important homelab units not active\n\n'
  local -a units
  read -r -a units <<<"$HOMELAB_IMPORTANT_UNITS"
  if output=$(unit_states system "${units[@]}") && [[ -n $output ]]; then
    local reported=0 unit active sub type
    while IFS=$'\t' read -r unit active sub type; do
      [[ $active == active ]] && continue
      if [[ $type == oneshot ]]; then
        printf -- '- %s: %s (%s; oneshot, inactive between runs)\n' "$unit" "$active" "$sub"
      else
        printf -- '- %s: %s (%s)\n' "$unit" "$active" "$sub"
      fi
      reported=1
    done <<<"$output"
    ((reported)) || printf -- '- none: all %d important units are active\n' "${#units[@]}"
    printf '\nOneshot services are expected to be inactive between timer runs; `failed` is the actionable state.\n'
  else
    mark_unknown "systemctl show did not answer for the important units"
  fi
}

section_agents() {
  local output unit active sub _type
  printf '## Agent services\n\n'

  if output=$(unit_states user t3code.service) && [[ -n $output ]]; then
    while IFS=$'\t' read -r unit active sub _type; do
      printf -- '- %s (user): %s (%s)\n' "$unit" "$active" "$sub"
    done <<<"$output"
  else
    mark_unknown "t3code.service (user) state unavailable"
  fi

  if output=$(unit_states system cliproxyapi.service cliproxyapi-quota.service cliproxyapi-readiness-probe.timer) && [[ -n $output ]]; then
    while IFS=$'\t' read -r unit active sub _type; do
      printf -- '- %s: %s (%s)\n' "$unit" "$active" "$sub"
    done <<<"$output"
  else
    mark_unknown "cliproxyapi system unit states unavailable"
  fi

  local ready
  if [[ -r $CLIPROXYAPI_READINESS_FILE ]] &&
    ready=$(grep -E '^cliproxyapi_backend_ready ' "$CLIPROXYAPI_READINESS_FILE" 2>/dev/null | tail -n 1 | awk '{print $2}') &&
    [[ -n $ready ]]; then
    printf -- '- cliproxyapi_backend_ready: %s (from %s)\n' "$ready" "$CLIPROXYAPI_READINESS_FILE"
  else
    mark_unknown "cliproxyapi_backend_ready not readable from $CLIPROXYAPI_READINESS_FILE (probe not deployed or no sample yet)"
  fi
}

section_quota() {
  local json lines
  printf '## Quota availability\n\n'
  if ! command -v cliproxyapi-util >/dev/null 2>&1; then
    mark_unknown "cliproxyapi-util is not installed"
    return
  fi
  if json=$(timeout "$command_timeout" cliproxyapi-util quota --json 2>/dev/null) &&
    lines=$(jq -r '.families[] | "\(.family): \(.status), used \(if .usedPercent == null then "unknown" else (.usedPercent | tostring) + "%" end)"' <<<"$json" 2>/dev/null); then
    printf '%s\n' "$lines" | bullets_or "no quota families reported"
  else
    mark_unknown "cliproxyapi-util quota --json failed or returned unexpected output"
  fi
}

section_decisions() {
  local json lines
  printf '## Awaiting a decision\n\n'
  if ! command -v gh >/dev/null 2>&1; then
    mark_unknown "gh is not installed"
    return
  fi
  if ! timeout "$command_timeout" gh auth status >/dev/null 2>&1; then
    mark_unknown "gh is not authenticated"
    return
  fi
  if json=$(timeout "$command_timeout" gh pr list --repo "$MORNING_REPORT_GITHUB_REPO" --state open \
    --json number,title,reviewDecision,isDraft,updatedAt 2>/dev/null) &&
    lines=$(jq -r '.[] | "#\(.number) \(.title) — \(if (.reviewDecision // "") == "" then "no review decision" else .reviewDecision end)\(if .isDraft then ", draft" else "" end), updated \(.updatedAt)"' <<<"$json" 2>/dev/null); then
    printf 'Open pull requests in %s:\n\n' "$MORNING_REPORT_GITHUB_REPO"
    printf '%s\n' "$lines" | bullets_or "none open"
  else
    mark_unknown "gh pr list failed for $MORNING_REPORT_GITHUB_REPO"
  fi
}

section_repository() {
  local output
  printf '## Repository\n\n'
  printf -- '- Path: %s\n' "$MORNING_REPORT_REPO"
  if output=$(timeout "$command_timeout" git -C "$MORNING_REPORT_REPO" status --porcelain 2>/dev/null | wc -l); then
    printf -- '- Uncommitted changes: %s\n' "$((output))"
  else
    mark_unknown "git status failed"
  fi
  if output=$(timeout "$command_timeout" git -C "$MORNING_REPORT_REPO" rev-parse --abbrev-ref HEAD 2>/dev/null) && [[ -n $output ]]; then
    printf -- '- Checked-out branch: %s\n' "$output"
  else
    mark_unknown "current branch unavailable"
  fi
  if output=$(timeout "$command_timeout" git -C "$MORNING_REPORT_REPO" log -1 --format='%h %s' main 2>/dev/null) && [[ -n $output ]]; then
    printf -- '- Latest commit on main: %s\n' "$output"
  else
    mark_unknown "latest commit on main unavailable"
  fi
}

render_report() {
  local host script_hash
  host=$(uname -n 2>/dev/null || printf '%s' "$unknown")
  script_hash=$(sha256sum "${BASH_SOURCE[0]}" 2>/dev/null | cut -c1-12 || printf '%s' "$unknown")

  printf '# Morning report %s (%s)\n\n' "$today" "$host"
  section_systemd
  printf '\n'
  section_agents
  printf '\n'
  section_quota
  printf '\n'
  section_decisions
  printf '\n'
  section_repository
  printf '\n---\n\n'
  printf 'Generated %s on %s by morning-report (script sha256 %s).\n' "$(date --iso-8601=seconds)" "$host" "$script_hash"
  printf 'This report performed no changes: it only read systemd state, local files, gh, and git.\n'
}

render_report >"$report_tmp"
chmod 0644 "$report_tmp"
mv -f -T "$report_tmp" "$report_file"
trap - EXIT
rm -rf "$scratch"
