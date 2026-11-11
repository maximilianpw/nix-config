#!/usr/bin/env bash

: "${BORG_BIN:?BORG_BIN must be set}" "${DATE_BIN:?DATE_BIN must be set}"
: "${FLOCK_BIN:?FLOCK_BIN must be set}"
: "${BORG_OPERATION_LOCK_FILE:?BORG_OPERATION_LOCK_FILE must be set}"
: "${HOMELAB_BACKUP_METRICS_DIR:?HOMELAB_BACKUP_METRICS_DIR must be set}"

exec 9>"$BORG_OPERATION_LOCK_FILE"
"$FLOCK_BIN" 9
check_started_epoch=$($DATE_BIN +%s)
"$BORG_BIN" check --lock-wait 60 --repository-only --max-duration 3600
"$BORG_BIN" check --lock-wait 60 --archives-only --last 1
check_finished_epoch=$($DATE_BIN +%s)
metrics_tmp="$HOMELAB_BACKUP_METRICS_DIR/homelab-borg-check.prom.tmp"
{
  printf 'homelab_borg_check_last_success_timestamp_seconds %s\n' "$check_finished_epoch"
  printf 'homelab_borg_check_last_duration_seconds %s\n' "$((check_finished_epoch - check_started_epoch))"
} > "$metrics_tmp"
chmod 0644 "$metrics_tmp"
mv -f "$metrics_tmp" "$HOMELAB_BACKUP_METRICS_DIR/homelab-borg-check.prom"
