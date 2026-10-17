#!/usr/bin/env bash
# Write one read-only Markdown status report. Every section degrades to an
# explicit "unknown" marker when its source is unavailable; the only non-zero
# exits are setup failures and a report that could not be written. The run
# writes exactly the report file (through a temporary file beside it) and a
# scratch directory it removes; systemd, services, repositories, and data are
# only read, and git runs with optional locks disabled.
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
# Kill children that ignore TERM so a hung source cannot stall the report.
kill_after=5

if ! today=$(date +%F) || [[ -z $today ]]; then
  echo "morning-report: could not determine today's date" >&2
  exit 1
fi
report_file="$MORNING_REPORT_DIR/$today.md"

# The trap is installed before any allocation and tolerates empty paths so a
# failure between the two mktemp calls cannot orphan the temporary report.
report_tmp=""
scratch=""
cleanup() {
  if [[ -n $report_tmp ]]; then
    rm -f -- "$report_tmp"
  fi
  if [[ -n $scratch ]]; then
    rm -rf -- "$scratch"
  fi
}
trap cleanup EXIT

mkdir -p "$MORNING_REPORT_DIR"
report_tmp=$(mktemp "$report_file.XXXXXX")
scratch=$(mktemp -d)

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

# Print one record per unit as unit, LoadState, ActiveState, SubState, and
# Type separated by the ASCII unit separator (0x1f), which `read` never
# collapses the way it collapses whitespace, so empty fields keep their slot.
# systemd does not promise property order, so each blank-line-delimited record
# is accumulated by key and flushed only at the blank line or at the end.
unit_states() {
  local scope=$1
  shift
  local -a scope_flag=()
  [[ $scope == user ]] && scope_flag=(--user)
  timeout -k "$kill_after" "$command_timeout" systemctl "${scope_flag[@]}" show \
    --property=Id --property=LoadState --property=ActiveState --property=SubState --property=Type -- "$@" 2>/dev/null |
    awk -v us="\037" '
      function flush() {
        if (seen) {
          print rec["Id"] us rec["LoadState"] us rec["ActiveState"] us rec["SubState"] us rec["Type"]
        }
        split("", rec)
        seen = 0
      }
      /^$/ { flush(); next }
      {
        key = $0
        sub(/=.*/, "", key)
        rec[key] = substr($0, length(key) + 2)
        seen = 1
      }
      END { flush() }
    '
}

# Describe a unit's state for a bullet; units systemd could not load are
# reported by load state so they are never mistaken for inactive units.
describe_unit() {
  local load=$1 active=$2 sub=$3
  if [[ -n $load && $load != loaded ]]; then
    printf 'not loaded (%s)' "$load"
  else
    printf '%s (%s)' "$active" "$sub"
  fi
}

failed_units() {
  local scope=$1
  local -a scope_flag=()
  [[ $scope == user ]] && scope_flag=(--user)
  timeout -k "$kill_after" "$command_timeout" systemctl "${scope_flag[@]}" --failed --no-legend --plain 2>/dev/null
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
    local reported=0 unit load active sub type
    while IFS=$'\037' read -r unit load active sub type; do
      [[ $load == loaded && $active == active ]] && continue
      # Only a genuinely inactive oneshot is "between runs"; a failed oneshot
      # is actionable and must read as failed.
      if [[ $load == loaded && $type == oneshot && $active == inactive ]]; then
        printf -- '- %s: %s (%s; oneshot, inactive between runs)\n' "$unit" "$active" "$sub"
      else
        printf -- '- %s: %s\n' "$unit" "$(describe_unit "$load" "$active" "$sub")"
      fi
      reported=1
    done <<<"$output"
    ((reported)) || printf -- '- none: all %d important units are active\n' "${#units[@]}"
    printf '\nOneshot services are expected to be inactive between timer runs; `failed` and `not loaded` are the actionable states.\n'
  else
    mark_unknown "systemctl show did not answer for the important units"
  fi
}

section_agents() {
  local output unit load active sub _type
  printf '## Agent services\n\n'

  if output=$(unit_states user t3code.service) && [[ -n $output ]]; then
    while IFS=$'\037' read -r unit load active sub _type; do
      printf -- '- %s (user): %s\n' "$unit" "$(describe_unit "$load" "$active" "$sub")"
    done <<<"$output"
  else
    mark_unknown "t3code.service (user) state unavailable"
  fi

  if output=$(unit_states system cliproxyapi.service cliproxyapi-quota.service cliproxyapi-readiness-probe.timer) && [[ -n $output ]]; then
    while IFS=$'\037' read -r unit load active sub _type; do
      printf -- '- %s: %s\n' "$unit" "$(describe_unit "$load" "$active" "$sub")"
    done <<<"$output"
  else
    mark_unknown "cliproxyapi system unit states unavailable"
  fi

  local ready
  if [[ -r $CLIPROXYAPI_READINESS_FILE ]] &&
    ready=$(timeout -k "$kill_after" "$command_timeout" grep -E '^cliproxyapi_backend_ready ' "$CLIPROXYAPI_READINESS_FILE" 2>/dev/null | tail -n 1 | awk '{print $2}') &&
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
  # jq's error() exits non-zero, so a payload whose shape drifted is reported
  # as unknown instead of rendering "null: null" bullets.
  if json=$(timeout -k "$kill_after" "$command_timeout" cliproxyapi-util quota --json 2>/dev/null) &&
    [[ -n $json ]] &&
    lines=$(jq -r '
      if (.families | type) != "array" then error("families must be an array") else . end
      | .families[]
      | if (.family | type) != "string" or (.status | type) != "string" then error("family entries need string family and status") else . end
      | "\(.family): \(.status), used \(if .usedPercent == null then "unknown" else (.usedPercent | tostring) + "%" end)"
    ' <<<"$json" 2>/dev/null); then
    printf '%s\n' "$lines" | bullets_or "no quota families reported"
  else
    mark_unknown "cliproxyapi-util quota --json failed or returned unexpected output"
  fi
}

# Exit statuses `timeout` reserves for a child it had to stop.
timed_out() {
  [[ $1 == 124 || $1 == 137 ]]
}

section_decisions() {
  local json lines status=0
  printf '## Awaiting a decision\n\n'
  if ! command -v gh >/dev/null 2>&1; then
    mark_unknown "gh is not installed"
    return
  fi
  timeout -k "$kill_after" "$command_timeout" gh auth status >/dev/null 2>&1 || status=$?
  if timed_out "$status"; then
    mark_unknown "gh auth status timed out after ${command_timeout}s (network or GitHub unavailable)"
    return
  elif ((status != 0)); then
    mark_unknown "gh is not authenticated or could not reach GitHub (gh auth status exited $status)"
    return
  fi
  status=0
  json=$(timeout -k "$kill_after" "$command_timeout" gh pr list --repo "$MORNING_REPORT_GITHUB_REPO" --state open \
    --json number,title,reviewDecision,isDraft,updatedAt 2>/dev/null) || status=$?
  if timed_out "$status"; then
    mark_unknown "gh pr list timed out after ${command_timeout}s for $MORNING_REPORT_GITHUB_REPO"
    return
  fi
  if ((status == 0)) && [[ -n $json ]] &&
    lines=$(jq -r '
      if type != "array" then error("pull request list must be an array") else . end
      | .[]
      | "#\(.number) \(.title) — \(if (.reviewDecision // "") == "" then "no review decision" else .reviewDecision end)\(if .isDraft then ", draft" else "" end), updated \(.updatedAt)"
    ' <<<"$json" 2>/dev/null); then
    printf 'Open pull requests in %s:\n\n' "$MORNING_REPORT_GITHUB_REPO"
    printf '%s\n' "$lines" | bullets_or "none open"
  else
    mark_unknown "gh pr list failed or returned unexpected output for $MORNING_REPORT_GITHUB_REPO"
  fi
}

section_repository() {
  local output
  printf '## Repository\n\n'
  printf -- '- Path: %s\n' "$MORNING_REPORT_REPO"
  # --no-optional-locks keeps `git status` from refreshing the index on disk.
  if output=$(timeout -k "$kill_after" "$command_timeout" git --no-optional-locks -C "$MORNING_REPORT_REPO" status --porcelain 2>/dev/null | wc -l); then
    printf -- '- Uncommitted changes: %s\n' "$((output))"
  else
    mark_unknown "git status failed"
  fi
  if output=$(timeout -k "$kill_after" "$command_timeout" git --no-optional-locks -C "$MORNING_REPORT_REPO" rev-parse --abbrev-ref HEAD 2>/dev/null) && [[ -n $output ]]; then
    printf -- '- Checked-out branch: %s\n' "$output"
  else
    mark_unknown "current branch unavailable"
  fi
  if output=$(timeout -k "$kill_after" "$command_timeout" git --no-optional-locks -C "$MORNING_REPORT_REPO" log -1 --format='%h %s' main 2>/dev/null) && [[ -n $output ]]; then
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
  printf 'This run wrote only this report file (through a temporary file beside it) and a scratch directory it removed; systemd state, local files, gh, and git were only read, with git optional locks disabled.\n'
}

render_report >"$report_tmp"
# The report names open pull requests and commit subjects; keep it owner-only.
chmod 0600 "$report_tmp"
mv -f -T "$report_tmp" "$report_file"
trap - EXIT
# Publication succeeded above; scratch cleanup must not change the exit status.
rm -rf -- "$scratch" || true
