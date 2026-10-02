#!/usr/bin/env bash
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
cat >"$STUB_DIR/states-system" <<'EOF'
alpha.service active running simple
beta.timer active waiting -
gamma.service inactive dead oneshot
delta.service failed failed simple
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
    first=1
    for arg in "$@"; do
      case $arg in
        show | --property=* | --) continue ;;
      esac
      ((first)) || printf '\n'
      first=0
      line=$(grep -F -- "$arg " "$STUB_DIR/states-$scope" | head -n 1 || true)
      if [[ -z $line ]]; then
        printf 'Id=%s\nActiveState=inactive\nSubState=dead\n' "$arg"
        continue
      fi
      read -r _ active sub type <<<"$line"
      printf 'Id=%s\nActiveState=%s\nSubState=%s\n' "$arg" "$active" "$sub"
      [[ $type == - ]] || printf 'Type=%s\n' "$type"
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
      HOMELAB_IMPORTANT_UNITS="alpha.service beta.timer gamma.service delta.service" \
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

today=$(date +%F)

# (a) every source healthy
healthy_dir="$tmp/reports/healthy"
: >"$STUB_DIR/calls.log"
run_report "$stubs:$tools" "$healthy_dir" env
report="$healthy_dir/$today.md"
[[ -f $report ]] || fail "healthy run did not write $report"
assert_file_mode "$report" 0644
test -z "$(find "$healthy_dir" -mindepth 1 ! -name "$today.md" -print -quit)" || fail "healthy run left extra files"
expect_line "$report" "# Morning report $today"
expect_line "$report" "## Failed or degraded systemd units"
expect_line "$report" "### System units reported failed"
expect_line "$report" "- broken-user.service loaded failed failed Broken user job"
expect_line "$report" "- gamma.service: inactive (dead; oneshot, inactive between runs)"
expect_line "$report" "- delta.service: failed (failed)"
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
expect_line "$report" "This report performed no changes"
expect_line "$report" "by morning-report (script sha256 "
if grep -q '^- unknown:' "$report"; then
  cat "$report" >&2
  fail "healthy run reported unknown sections"
fi
# alpha.service and beta.timer are active and must not be listed.
if grep -Eq '^- (alpha\.service|beta\.timer):' "$report"; then
  fail "active important units were listed as degraded"
fi
grep -Fq -- "git -C $fake_repo status --porcelain" "$STUB_DIR/calls.log" || fail "git was not scoped to the repository"
grep -Fq -- "gh pr list --repo maximilianpw/nix-config" "$STUB_DIR/calls.log" || fail "gh pr list was not scoped to the repository"

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
expect_line "$report" "- unknown: gh is not authenticated"
expect_line "$report" "- unknown: git status failed"
expect_line "$report" "- unknown: current branch unavailable"
expect_line "$report" "- unknown: latest commit on main unavailable"
expect_line "$report" "This report performed no changes"
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
test -z "$(find "$collision_dir" -mindepth 1 ! -name "$today.md" -print -quit)" || fail "failed write left a temporary file behind"

# (d) dotenv files are never read
if grep -Fq -- '.env' "$script"; then
  fail "script must not reference dotenv files"
fi
for report in "$healthy_dir/$today.md" "$failing_dir/$today.md" "$sparse_dir/$today.md"; do
  if grep -Fq -- "$sentinel" "$report"; then
    fail "report leaked the dotenv sentinel"
  fi
done

echo "morning report tests passed"
