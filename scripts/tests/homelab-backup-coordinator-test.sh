#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
coordinator="$repo_root/scripts/homelab-backup-coordinator.sh"
posthook="$repo_root/scripts/homelab-backup-posthook.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
command=$1
shift
if [[ ${1:-} == --quiet ]]; then shift; fi
unit=${1:-}
printf '%s %s\n' "$command" "$*" >> "$CASE_DIR/commands"
case "$command" in
  is-active)
    grep -Fxq "$unit" "$CASE_DIR/active"
    ;;
  stop)
    for unit in "$@"; do
      if [[ $unit == "${FAIL_STOP_UNIT:-}" ]]; then exit 1; fi
      grep -Fxv "$unit" "$CASE_DIR/active" > "$CASE_DIR/active.new" || true
      mv "$CASE_DIR/active.new" "$CASE_DIR/active"
    done
    ;;
  start)
    for unit in "$@"; do
      if [[ $unit == "${FAIL_START_UNIT:-}" ]]; then exit 1; fi
      grep -Fxq "$unit" "$CASE_DIR/active" || printf '%s\n' "$unit" >> "$CASE_DIR/active"
    done
    ;;
  *) exit 2 ;;
esac
EOF
# Each preparation step logs its name and fails when FAIL_STEP names it.
for step in snapshot export dump; do
  cat > "$tmp/step-$step" <<EOF
#!/usr/bin/env bash
printf 'step $step\n' >> "\$CASE_DIR/commands"
[[ \${FAIL_STEP:-} != $step ]]
EOF
  chmod +x "$tmp/step-$step"
done
printf 'online\tsnapshot\t%s\nquiesced\texport\t%s\nquiesced\tdump\t%s\n' \
  "$tmp/step-snapshot" "$tmp/step-export" "$tmp/step-dump" > "$tmp/steps"
chmod +x "$tmp/systemctl"

new_case() {
  local name=$1
  CASE_DIR="$tmp/$name"
  export CASE_DIR
  mkdir -p "$CASE_DIR/state"
  : > "$CASE_DIR/active"
  : > "$CASE_DIR/commands"
  export SYSTEMCTL_BIN=$tmp/systemctl
  export HOMELAB_PREPARE_STEPS_FILE=$tmp/steps
  export HOMELAB_BACKUP_STATE_DIR=$CASE_DIR/state
  export HOMELAB_DUMP_UNITS='db-a.service db-inactive.service'
  export HOMELAB_ARCHIVE_UNITS='file-a.service file-b.service'
  unset FAIL_STOP_UNIT FAIL_START_UNIT FAIL_STEP
}

is_active() {
  grep -Fxq "$1" "$CASE_DIR/active"
}
line_of() {
  grep -Fxn "$1" "$CASE_DIR/commands" | head -n 1 | cut -d: -f1
}
expect_prepare_failure() {
  if bash "$coordinator" prepare; then
    echo "$1 unexpectedly allowed backup preparation" >&2
    exit 1
  fi
}

# Normal lifecycle, including a pre-existing inactive service: online steps,
# then stops, then quiesced steps in file order, then dump units restart.
new_case normal
printf '%s\n' db-a.service file-a.service file-b.service > "$CASE_DIR/active"
bash "$coordinator" prepare
(($(line_of 'step snapshot') < $(line_of 'stop db-a.service')))
(($(line_of 'stop file-b.service') < $(line_of 'step export')))
(($(line_of 'step export') < $(line_of 'step dump')))
(($(line_of 'step dump') < $(line_of 'start db-a.service')))
is_active db-a.service
! is_active db-inactive.service
! is_active file-a.service
bash "$coordinator" cleanup
is_active file-a.service
is_active file-b.service
! is_active db-inactive.service
[[ ! -e $CASE_DIR/state/active-units ]]

# A failed online step happens before any service is stopped. The persisted
# active-unit state still lets final cleanup complete safely.
new_case online-step-failure
printf '%s\n' db-a.service file-a.service > "$CASE_DIR/active"
export FAIL_STEP=snapshot
expect_prepare_failure "failed online step"
unset FAIL_STEP
is_active db-a.service
is_active file-a.service
if grep -Eq '^stop ' "$CASE_DIR/commands"; then
  echo "online step failure stopped a service" >&2
  exit 1
fi
bash "$coordinator" cleanup
[[ ! -e $CASE_DIR/state/active-units ]]

# Failure before exports still leaves enough persisted state for cleanup.
new_case stop-failure
printf '%s\n' db-a.service file-a.service > "$CASE_DIR/active"
export FAIL_STOP_UNIT=file-a.service
expect_prepare_failure "stop failure"
unset FAIL_STOP_UNIT
bash "$coordinator" cleanup
is_active db-a.service
is_active file-a.service

# A failed quiesced step stops later steps and cleanup recovers every unit.
new_case quiesced-step-failure
printf '%s\n' db-a.service file-a.service > "$CASE_DIR/active"
export FAIL_STEP=export
expect_prepare_failure "failed quiesced step"
unset FAIL_STEP
! grep -Fxq 'step dump' "$CASE_DIR/commands"
bash "$coordinator" cleanup
is_active db-a.service
is_active file-a.service

# One restart failure is reported while later services are still attempted.
new_case restart-failure
printf '%s\n' file-a.service file-b.service > "$CASE_DIR/active"
bash "$coordinator" prepare
export FAIL_START_UNIT=file-a.service
if bash "$coordinator" cleanup; then
  echo "restart failure unexpectedly succeeded" >&2
  exit 1
fi
is_active file-b.service
grep -Fq 'start file-b.service' "$CASE_DIR/commands"

# Unresolved restart state blocks a later backup instead of forgetting a unit.
new_case stale-state
printf 'archive\tfile-a.service\n' > "$CASE_DIR/state/active-units"
if bash "$coordinator" prepare; then
  echo "backup unexpectedly replaced unresolved restart state" >&2
  exit 1
fi
grep -Fq $'archive\tfile-a.service' "$CASE_DIR/state/active-units"

# Exercise the same final-status contract used by the generated Borg EXIT trap.
cat > "$tmp/posthook-coordinator" <<'EOF'
#!/usr/bin/env bash
exit "${POSTHOOK_CLEANUP_STATUS:?}"
EOF
chmod +x "$tmp/posthook-coordinator"

run_posthook_case() {
  local name=$1 backup_status=$2 cleanup_status=$3 expected_status=$4 expect_metrics=$5
  local metrics_dir="$tmp/posthook-$name"
  mkdir -p "$metrics_dir"
  export HOMELAB_COORDINATOR_BIN=$tmp/posthook-coordinator
  export DATE_BIN
  DATE_BIN=$(command -v date)
  export HOMELAB_BACKUP_METRICS_DIR=$metrics_dir
  export POSTHOOK_CLEANUP_STATUS=$cleanup_status

  set +e
  HOMELAB_HEARTBEAT_BIN=${POSTHOOK_HEARTBEAT_BIN:-} \
    bash "$posthook" "$backup_status" 100 > "$metrics_dir/out" 2> "$metrics_dir/err"
  actual_status=$?
  set -e
  [[ $actual_status -eq $expected_status ]]
  if [[ $expect_metrics == yes ]]; then
    grep -Fq 'homelab_backup_last_success_timestamp_seconds' "$metrics_dir/homelab-backup.prom"
  else
    [[ ! -e $metrics_dir/homelab-backup.prom ]]
  fi
}

run_posthook_case success 0 0 0 yes
run_posthook_case borg-failed 2 0 2 no
run_posthook_case cleanup-failed 0 1 1 no
run_posthook_case both-failed 2 1 2 no

cat > "$tmp/posthook-heartbeat" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" > "$POSTHOOK_HEARTBEAT_ACTION_FILE"
EOF
chmod +x "$tmp/posthook-heartbeat"
export POSTHOOK_HEARTBEAT_BIN=$tmp/posthook-heartbeat
export POSTHOOK_HEARTBEAT_ACTION_FILE=$tmp/posthook-heartbeat-action
run_posthook_case heartbeat-success 0 0 0 yes
grep -Fxq success "$POSTHOOK_HEARTBEAT_ACTION_FILE"
run_posthook_case heartbeat-failure 2 0 2 no
grep -Fxq fail "$POSTHOOK_HEARTBEAT_ACTION_FILE"

echo "homelab backup coordinator tests passed"
