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
raw_args=$*
scope=system
user=-
while [[ ${1:-} == --* ]]; do
  case "$1" in
    --user) scope=user ;;
    --machine=*) user=${1#--machine=}; user=${user%@.host} ;;
    *) exit 2 ;;
  esac
  shift
done
command=$1
shift
if [[ ${1:-} == --quiet ]]; then shift; fi
unit=${1:-}
if [[ $scope == user ]]; then
  key="$user:$unit"
else
  key=$unit
fi
printf 'RAW %s\n' "$raw_args" >> "$CASE_DIR/commands"
printf '%s %s\n' "$command" "$*" >> "$CASE_DIR/commands"
case "$command" in
  list-units)
    if [[ $scope == user && ${SYSTEMCTL_USER_MANAGER_FAIL:-0} == 1 ]]; then
      exit 1
    fi
    ;;
  is-active)
    if [[ $unit == nextcloud-update-store-apps.service && ${UPDATE_STUCK:-0} == 1 ]]; then
      exit 0
    fi
    grep -Fxq "$key" "$CASE_DIR/active"
    ;;
  stop)
    for unit in "$@"; do
      if [[ $scope == user ]]; then key="$user:$unit"; else key=$unit; fi
      if [[ $key == "${FAIL_STOP_UNIT:-}" ]]; then exit 1; fi
      grep -Fxv "$key" "$CASE_DIR/active" > "$CASE_DIR/active.new" || true
      mv "$CASE_DIR/active.new" "$CASE_DIR/active"
    done
    ;;
  start)
    for unit in "$@"; do
      if [[ $scope == user ]]; then key="$user:$unit"; else key=$unit; fi
      if [[ $key == "${FAIL_START_UNIT:-}" ]]; then exit 1; fi
      grep -Fxq "$key" "$CASE_DIR/active" || printf '%s\n' "$key" >> "$CASE_DIR/active"
    done
    ;;
  *) exit 2 ;;
esac
EOF
cat > "$tmp/tar-fail" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$tmp/systemctl" "$tmp/tar-fail"

new_case() {
  local name=$1
  CASE_DIR="$tmp/$name"
  export CASE_DIR
  mkdir -p "$CASE_DIR/source/hass" "$CASE_DIR/archive" "$CASE_DIR/state"
  : > "$CASE_DIR/active"
  : > "$CASE_DIR/commands"
  printf 'config\n' > "$CASE_DIR/source/hass/configuration.yaml"
  export SYSTEMCTL_BIN=$tmp/systemctl
  export TAR_BIN
  TAR_BIN=$(command -v tar)
  export SLEEP_BIN
  SLEEP_BIN=$(command -v true)
  export HOMELAB_BACKUP_STATE_DIR=$CASE_DIR/state
  export HOME_ASSISTANT_SOURCE_DIR=$CASE_DIR/source
  export HOME_ASSISTANT_ARCHIVE_DIR=$CASE_DIR/archive
  export HOMELAB_DUMP_UNITS='db-a.service db-inactive.service'
  export HOMELAB_ARCHIVE_UNITS='file-a.service file-b.service'
  export HOMELAB_USER_DUMP_UNITS=''
  export HOMELAB_USER_ARCHIVE_UNITS='maxpw:t3code.service'
  export NEXTCLOUD_UPDATE_MAX_WAITS=1
  unset FAIL_STOP_UNIT FAIL_START_UNIT UPDATE_STUCK SYSTEMCTL_USER_MANAGER_FAIL
}

is_active() {
  grep -Fxq "$1" "$CASE_DIR/active"
}

# Normal lifecycle, including a pre-existing inactive service.
new_case normal
printf '%s\n' db-a.service file-a.service file-b.service maxpw:t3code.service > "$CASE_DIR/active"
bash "$coordinator" prepare
is_active db-a.service
! is_active db-inactive.service
! is_active file-a.service
! is_active maxpw:t3code.service
[[ -s $CASE_DIR/archive/config.tar ]]
bash "$coordinator" cleanup
is_active file-a.service
is_active file-b.service
is_active maxpw:t3code.service
! is_active db-inactive.service
[[ ! -e $CASE_DIR/state/active-units ]]
grep -Fq -- '--user --machine=maxpw@.host stop t3code.service' "$CASE_DIR/commands"

# A transport failure must not be mistaken for an inactive user unit and copied hot.
new_case user-manager-failure
printf '%s\n' maxpw:t3code.service > "$CASE_DIR/active"
export SYSTEMCTL_USER_MANAGER_FAIL=1
if bash "$coordinator" prepare; then
  echo "unreachable user manager unexpectedly allowed backup preparation" >&2
  exit 1
fi
unset SYSTEMCTL_USER_MANAGER_FAIL
if grep -Eq '^stop | stop ' "$CASE_DIR/commands"; then
  echo "prepare stopped units before validating the declared user manager" >&2
  exit 1
fi
is_active maxpw:t3code.service

# Failure before exports still leaves enough persisted state for cleanup.
new_case stop-failure
printf '%s\n' db-a.service file-a.service > "$CASE_DIR/active"
export FAIL_STOP_UNIT=file-a.service
if bash "$coordinator" prepare; then
  echo "stop failure unexpectedly succeeded" >&2
  exit 1
fi
unset FAIL_STOP_UNIT
bash "$coordinator" cleanup
is_active db-a.service
is_active file-a.service

# Home Assistant archive creation failure recovers all active units.
new_case tar-failure
printf '%s\n' db-a.service file-a.service > "$CASE_DIR/active"
export TAR_BIN=$tmp/tar-fail
if bash "$coordinator" prepare; then
  echo "tar failure unexpectedly succeeded" >&2
  exit 1
fi
export TAR_BIN
TAR_BIN=$(command -v tar)
bash "$coordinator" cleanup
is_active db-a.service
is_active file-a.service

# PostgreSQL dump failure recovers all active units.
new_case postgres-failure
printf '%s\n' db-a.service file-a.service > "$CASE_DIR/active"
export FAIL_START_UNIT=postgresqlBackup.service
if bash "$coordinator" prepare; then
  echo "PostgreSQL dump failure unexpectedly succeeded" >&2
  exit 1
fi
unset FAIL_START_UNIT
bash "$coordinator" cleanup
is_active db-a.service
is_active file-a.service

# A Borg failure occurs after successful preparation; cleanup returns file units.
new_case borg-failure
printf '%s\n' db-a.service file-a.service > "$CASE_DIR/active"
bash "$coordinator" prepare
# Simulated borg create exit 2: the generated post-hook invokes cleanup anyway.
bash "$coordinator" cleanup
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
printf 'archive\tsystem\t-\tfile-a.service\n' > "$CASE_DIR/state/active-units"
if bash "$coordinator" prepare; then
  echo "backup unexpectedly replaced unresolved restart state" >&2
  exit 1
fi
grep -Fq $'archive\tsystem\t-\tfile-a.service' "$CASE_DIR/state/active-units"

# A running Nextcloud updater times out instead of being killed mid-write.
new_case updater-timeout
printf '%s\n' file-a.service > "$CASE_DIR/active"
export UPDATE_STUCK=1
if bash "$coordinator" prepare; then
  echo "Nextcloud updater timeout unexpectedly succeeded" >&2
  exit 1
fi
unset UPDATE_STUCK
bash "$coordinator" cleanup
is_active file-a.service

# Preparation failure is not allowed to hide cleanup failure in the model: the
# cleanup command itself remains non-zero when any unit cannot restart.
new_case final-status
printf '%s\n' file-a.service > "$CASE_DIR/active"
bash "$coordinator" prepare
export FAIL_START_UNIT=file-a.service
if bash "$coordinator" cleanup; then
  echo "cleanup failure did not propagate a non-zero status" >&2
  exit 1
fi

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
