#!/usr/bin/env bash
# Registration: `make check-scripts` runs every scripts/tests/*-test.sh, and the
# CI `shell-safety` job (.github/workflows/ci.yml) runs `make check-scripts`
# inside `nix develop`. tests/morning-report-regression.nix covers the Nix
# wiring only; this file is the sole executor of the script's behaviour.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/scripts/morning-report.sh"
# shellcheck source=scripts/tests/portable-gnu-fixtures.sh
source "$repo_root/scripts/tests/portable-gnu-fixtures.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "morning-report test: $*" >&2
  exit 1
}

# Only the real tools the script needs are visible, so a host gh or
# cliproxyapi-util can never leak into a run; stubs are resolved first.
tools="$tmp/tools"
mkdir -p "$tools"
for tool in bash date mktemp mv rm mkdir chmod wc sha256sum uname timeout grep awk sed cut tail jq env head cat find; do
  ln -s "$(command -v "$tool")" "$tools/$tool"
done

export STUB_DIR="$tmp/stub-data"
mkdir -p "$STUB_DIR"
sentinel="SECRET_SENTINEL_$(date +%s)_do_not_leak"
fake_home="$tmp/home"
fake_repo="$fake_home/nix-config"
mkdir -p "$fake_repo"
printf 'API_TOKEN=%s\n' "$sentinel" >"$fake_home/.env"
printf 'API_TOKEN=%s\n' "$sentinel" >"$fake_repo/.env"
printf 'API_TOKEN=%s\n' "$sentinel" >"$fake_repo/.env.local"

readiness_file="$tmp/metrics/cliproxyapi-readiness.prom"
mkdir -p "$(dirname "$readiness_file")"
cat >"$readiness_file" <<'EOF'
# HELP cliproxyapi_backend_ready Whether the local CLIProxyAPI answered an authenticated model listing.
# TYPE cliproxyapi_backend_ready gauge
cliproxyapi_backend_ready 1
EOF

: >"$STUB_DIR/failed-system"
printf 'broken-user.service loaded failed failed Broken user job\n' >"$STUB_DIR/failed-user"
# unit ActiveState SubState Type; "-" means systemd reports no Type (timers).
# Units absent from this table are answered as LoadState=not-found.
cat >"$STUB_DIR/states-system" <<'EOF'
alpha.service active running simple
beta.timer active waiting -
gamma.service inactive dead oneshot
delta.service failed failed simple
zeta.service failed failed oneshot
cliproxyapi.service active running simple
cliproxyapi-quota.service failed failed simple
cliproxyapi-readiness-probe.timer active waiting -
EOF
cat >"$STUB_DIR/states-user" <<'EOF'
t3code.service active running simple
EOF

write_stubs() {
  local dir=$1
  mkdir -p "$dir"

  cat >"$dir/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl %s\n' "$*" >>"$STUB_DIR/calls.log"
[[ ${STUB_FAIL:-0} == 1 ]] && exit 1
scope=system
if [[ ${1:-} == --user ]]; then
  scope=user
  shift
fi
case $1 in
  --failed)
    cat "$STUB_DIR/failed-$scope"
    ;;
  show)
    # Properties are deliberately emitted in a different order from the
    # --property request, with Id last: systemd promises no order and the
    # parser must key on names, not positions.
    first=1
    for arg in "$@"; do
      case $arg in
        show | --property=* | --) continue ;;
      esac
      ((first)) || printf '\n'
      first=0
      line=$(grep -F -- "$arg " "$STUB_DIR/states-$scope" | head -n 1 || true)
      if [[ -z $line ]]; then
        printf 'SubState=dead\nActiveState=inactive\nLoadState=not-found\nId=%s\n' "$arg"
        continue
      fi
      read -r _ active sub type <<<"$line"
      printf 'SubState=%s\n' "$sub"
      [[ $type == - ]] || printf 'Type=%s\n' "$type"
      printf 'ActiveState=%s\nLoadState=loaded\nId=%s\n' "$active" "$arg"
    done
    ;;
  *)
    echo "unexpected systemctl invocation: $*" >&2
    exit 1
    ;;
esac
EOF

  cat >"$dir/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >>"$STUB_DIR/calls.log"
[[ ${STUB_FAIL:-0} == 1 ]] && exit 1
[[ $1 == --no-optional-locks ]] || { echo "git must be invoked with --no-optional-locks" >&2; exit 1; }
shift
[[ $1 == -C ]] || { echo "git must be invoked with -C" >&2; exit 1; }
shift 2
case $1 in
  status) printf ' M flake.nix\n?? scratch\n?? .env\n' ;;
  rev-parse) printf 'main\n' ;;
  log) printf 'abc1234 feat: stub commit\n' ;;
  *) echo "unexpected git invocation: $*" >&2; exit 1 ;;
esac
EOF

  cat >"$dir/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >>"$STUB_DIR/calls.log"
[[ ${STUB_FAIL:-0} == 1 ]] && exit 1
case "$1 $2" in
  "auth status") exit 0 ;;
  "pr list")
    cat <<'JSON'
[
  {"number": 31, "title": "feat(cliproxyapi): readiness probe", "reviewDecision": "", "isDraft": false, "updatedAt": "2026-10-01T18:00:00Z"},
  {"number": 32, "title": "docs: tidy", "reviewDecision": "APPROVED", "isDraft": true, "updatedAt": "2026-10-02T06:00:00Z"}
]
JSON
    ;;
  *) echo "unexpected gh invocation: $*" >&2; exit 1 ;;
esac
EOF

  cat >"$dir/cliproxyapi-util" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'cliproxyapi-util %s\n' "$*" >>"$STUB_DIR/calls.log"
[[ ${STUB_FAIL:-0} == 1 ]] && exit 1
# Bun auto-loads dotfiles from the working directory, so the report must run
# this command from an empty scratch directory.
if [[ -n $(find . -mindepth 1 -maxdepth 1 -print -quit) ]]; then
  echo "cliproxyapi-util must run from an empty directory, cwd=$PWD" >&2
  exit 1
fi
[[ $* == "quota --json" ]] || { echo "unexpected cliproxyapi-util invocation: $*" >&2; exit 1; }
cat <<'JSON'
{"version": 1, "families": [
  {"family": "codex", "status": "available", "usedPercent": 42, "readyAccounts": 1, "totalAccounts": 1},
  {"family": "claude", "status": "unavailable", "usedPercent": null, "readyAccounts": 0, "totalAccounts": 1}
]}
JSON
EOF
  chmod +x "$dir"/*
}

stubs="$tmp/stubs"
write_stubs "$stubs"

run_report() {
  local path=$1 report_dir=$2
  shift 2
  (
    cd "$fake_home"
    HOME="$fake_home" PATH="$path" \
      MORNING_REPORT_DIR="$report_dir" \
      MORNING_REPORT_REPO="$fake_repo" \
      MORNING_REPORT_GITHUB_REPO=maximilianpw/nix-config \
      HOMELAB_IMPORTANT_UNITS="alpha.service beta.timer gamma.service delta.service zeta.service epsilon.service" \
      CLIPROXYAPI_READINESS_FILE="$readiness_file" \
      "$@" bash "$script"
  )
}

expect_line() {
  local file=$1 pattern=$2
  grep -Fq -- "$pattern" "$file" || {
    echo "expected '$pattern' in report:" >&2
    cat "$file" >&2
    exit 1
  }
}

reject_line() {
  local file=$1 pattern=$2
  if grep -Fq -- "$pattern" "$file"; then
    echo "unexpected '$pattern' in report:" >&2
    cat "$file" >&2
    exit 1
  fi
}

only_file_in() {
  local dir=$1 name=$2
  test -z "$(find "$dir" -mindepth 1 ! -name "$name" -print -quit)"
}

today=$(date +%F)
footer="This run wrote only this report file"

# (a) every source healthy
healthy_dir="$tmp/reports/healthy"
: >"$STUB_DIR/calls.log"
run_report "$stubs:$tools" "$healthy_dir" env
report="$healthy_dir/$today.md"
[[ -f $report ]] || fail "healthy run did not write $report"
assert_file_mode "$report" 0600
only_file_in "$healthy_dir" "$today.md" || fail "healthy run left extra files"
expect_line "$report" "# Morning report $today"
expect_line "$report" "## Failed or degraded systemd units"
expect_line "$report" "### System units reported failed"
expect_line "$report" "- broken-user.service loaded failed failed Broken user job"
# Property order in `systemctl show` output must not matter: the stub emits
# Id last and omits Type for timers.
expect_line "$report" "- gamma.service: inactive (dead; oneshot, inactive between runs)"
expect_line "$report" "- delta.service: failed (failed)"
reject_line "$report" "- delta.service: failed (failed; oneshot"
# A failed oneshot is actionable and must never read as "between runs".
expect_line "$report" "- zeta.service: failed (failed)"
reject_line "$report" "- zeta.service: failed (failed; oneshot"
# A unit systemd cannot find is reported by load state, not as inactive.
expect_line "$report" "- epsilon.service: not loaded (not-found)"
reject_line "$report" "- epsilon.service: inactive"
expect_line "$report" "## Agent services"
expect_line "$report" "- t3code.service (user): active (running)"
expect_line "$report" "- cliproxyapi.service: active (running)"
expect_line "$report" "- cliproxyapi-quota.service: failed (failed)"
expect_line "$report" "- cliproxyapi-readiness-probe.timer: active (waiting)"
expect_line "$report" "- cliproxyapi_backend_ready: 1 (from $readiness_file)"
expect_line "$report" "## Quota availability"
expect_line "$report" "- codex: available, used 42%"
expect_line "$report" "- claude: unavailable, used unknown"
expect_line "$report" "## Awaiting a decision"
expect_line "$report" "- #31 feat(cliproxyapi): readiness probe — no review decision, updated 2026-10-01T18:00:00Z"
expect_line "$report" "- #32 docs: tidy — APPROVED, draft, updated 2026-10-02T06:00:00Z"
expect_line "$report" "## Repository"
expect_line "$report" "- Uncommitted changes: 3"
expect_line "$report" "- Checked-out branch: main"
expect_line "$report" "- Latest commit on main: abc1234 feat: stub commit"
expect_line "$report" "$footer"
expect_line "$report" "git optional locks disabled"
expect_line "$report" "by morning-report (script sha256 "
if grep -q '^- unknown:' "$report"; then
  cat "$report" >&2
  fail "healthy run reported unknown sections"
fi
# alpha.service and beta.timer are active and must not be listed.
if grep -Eq '^- (alpha\.service|beta\.timer):' "$report"; then
  fail "active important units were listed as degraded"
fi
grep -Fq -- "git --no-optional-locks -C $fake_repo status --porcelain" "$STUB_DIR/calls.log" || fail "git status was not scoped to the repository with optional locks disabled"
grep -Fq -- "systemctl show --property=Id --property=LoadState" "$STUB_DIR/calls.log" || fail "systemctl show did not request LoadState"
grep -Fq -- "gh pr list --repo maximilianpw/nix-config" "$STUB_DIR/calls.log" || fail "gh pr list was not scoped to the repository"

# (a2) a same-day re-run replaces the previous report and leaves one file
rerun_dir="$tmp/reports/rerun"
run_report "$stubs:$tools" "$rerun_dir" env
report="$rerun_dir/$today.md"
expect_line "$report" "- gamma.service: inactive"
first_inode=$(stat -c %i "$report")
run_report "$stubs:$tools" "$rerun_dir" env HOMELAB_IMPORTANT_UNITS="alpha.service"
[[ -f $report ]] || fail "same-day re-run removed the report"
only_file_in "$rerun_dir" "$today.md" || fail "same-day re-run left more than one file"
expect_line "$report" "- none: all 1 important units are active"
reject_line "$report" "- gamma.service: inactive"
[[ $(stat -c %i "$report") != "$first_inode" ]] || fail "same-day re-run rewrote the report in place instead of replacing it"
assert_file_mode "$report" 0600

# (b) every source failing still yields a report with unknown markers and exit 0
failing_dir="$tmp/reports/failing"
run_report "$stubs:$tools" "$failing_dir" env STUB_FAIL=1 \
  CLIPROXYAPI_READINESS_FILE="$tmp/metrics/missing.prom" \
  MORNING_REPORT_REPO="$tmp/missing-repo" ||
  fail "failing sources must not make the report exit non-zero"
report="$failing_dir/$today.md"
[[ -f $report ]] || fail "failing run did not write $report"
expect_line "$report" "- unknown: systemctl --failed did not answer"
expect_line "$report" "- unknown: systemctl --user --failed did not answer"
expect_line "$report" "- unknown: systemctl show did not answer for the important units"
expect_line "$report" "- unknown: t3code.service (user) state unavailable"
expect_line "$report" "- unknown: cliproxyapi system unit states unavailable"
expect_line "$report" "- unknown: cliproxyapi_backend_ready not readable from $tmp/metrics/missing.prom"
expect_line "$report" "- unknown: cliproxyapi-util quota --json failed or returned unexpected output"
expect_line "$report" "- unknown: gh is not authenticated or could not reach GitHub (gh auth status exited 1)"
expect_line "$report" "- unknown: git status failed"
expect_line "$report" "- unknown: current branch unavailable"
expect_line "$report" "- unknown: latest commit on main unavailable"
expect_line "$report" "$footer"
for section in "## Failed or degraded systemd units" "## Agent services" "## Quota availability" "## Awaiting a decision" "## Repository"; do
  expect_line "$report" "$section"
done

# (b2) optional tools absent are reported as not installed
sparse_stubs="$tmp/stubs-sparse"
mkdir -p "$sparse_stubs"
cp "$stubs/systemctl" "$stubs/git" "$sparse_stubs/"
sparse_dir="$tmp/reports/sparse"
run_report "$sparse_stubs:$tools" "$sparse_dir" env
report="$sparse_dir/$today.md"
expect_line "$report" "- unknown: cliproxyapi-util is not installed"
expect_line "$report" "- unknown: gh is not installed"

# (b3) a hung gh is reported as a timeout, not as missing authentication, and
# payloads of the wrong shape are unknown rather than rendered as null fields.
shaped_stubs="$tmp/stubs-shaped"
mkdir -p "$shaped_stubs"
cp "$stubs/systemctl" "$stubs/git" "$shaped_stubs/"
cat >"$shaped_stubs/gh" <<'EOF'
#!/usr/bin/env bash
# Mimic `timeout` having stopped gh: exit with its timeout status.
exit 124
EOF
cat >"$shaped_stubs/cliproxyapi-util" <<'EOF'
#!/usr/bin/env bash
printf '{"version": 1, "families": {"codex": "available"}}\n'
EOF
chmod +x "$shaped_stubs"/*
shaped_dir="$tmp/reports/shaped"
run_report "$shaped_stubs:$tools" "$shaped_dir" env
report="$shaped_dir/$today.md"
expect_line "$report" "- unknown: gh auth status timed out after 60s"
reject_line "$report" "gh is not authenticated"
expect_line "$report" "- unknown: cliproxyapi-util quota --json failed or returned unexpected output"
reject_line "$report" "null"

# (c) atomic output: a failed write leaves no partial file behind
blocked_parent="$tmp/reports/blocked"
: >"$blocked_parent"
if run_report "$stubs:$tools" "$blocked_parent/morning" env 2>/dev/null; then
  fail "report under an unwritable path must exit non-zero"
fi
[[ -f $blocked_parent && ! -s $blocked_parent ]] || fail "unwritable path test changed the blocking file"

collision_dir="$tmp/reports/collision"
mkdir -p "$collision_dir/$today.md"
if run_report "$stubs:$tools" "$collision_dir" env 2>/dev/null; then
  fail "report that cannot replace its destination must exit non-zero"
fi
[[ -d $collision_dir/$today.md ]] || fail "collision test removed the pre-existing directory"
only_file_in "$collision_dir" "$today.md" || fail "failed write left a temporary file behind"

# (c2) a scratch-directory allocation failure after the report temp file was
# created must remove that temp file and leave an existing report untouched.
# `mktemp -d` honours TMPDIR while the report template is an absolute path.
scratch_fail_dir="$tmp/reports/scratch-fail"
mkdir -p "$scratch_fail_dir"
printf 'previous report\n' >"$scratch_fail_dir/$today.md"
if run_report "$stubs:$tools" "$scratch_fail_dir" env TMPDIR="$tmp/no-such-tmpdir" 2>/dev/null; then
  fail "scratch allocation failure must exit non-zero"
fi
only_file_in "$scratch_fail_dir" "$today.md" || fail "scratch allocation failure orphaned the temporary report"
[[ $(cat "$scratch_fail_dir/$today.md") == "previous report" ]] || fail "scratch allocation failure altered the existing report"

# (d) dotenv files are never read
if grep -Fq -- '.env' "$script"; then
  fail "script must not reference dotenv files"
fi
for report in "$healthy_dir/$today.md" "$rerun_dir/$today.md" "$failing_dir/$today.md" "$sparse_dir/$today.md" "$shaped_dir/$today.md"; do
  if grep -Fq -- "$sentinel" "$report"; then
    fail "report leaked the dotenv sentinel"
  fi
done

echo "morning report tests passed"
