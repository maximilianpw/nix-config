#!/usr/bin/env bash
# Finalizes a Borg run after always attempting service recovery. The return value
# is the status that the upstream Borg EXIT trap should propagate.
set -euo pipefail

: "${HOMELAB_COORDINATOR_BIN:=homelab-backup-coordinator}"
: "${HOMELAB_BACKUP_METRICS_DIR:=/var/lib/prometheus-node-exporter-text-files}"
: "${DATE_BIN:=date}"
: "${HOMELAB_HEARTBEAT_BIN:=}"

if (( $# != 2 )); then
  echo "Usage: homelab-backup-posthook <borg-status> <started-epoch>" >&2
  exit 2
fi

backup_exit_status=$1
backup_started_epoch=$2
if [[ ! $backup_exit_status =~ ^[0-9]+$ || ! $backup_started_epoch =~ ^[0-9]+$ ]]; then
  echo "Borg status and start time must be non-negative integers" >&2
  exit 2
fi

cleanup_failed=0
if ! "$HOMELAB_COORDINATOR_BIN" cleanup; then
  cleanup_failed=1
fi

final_status=$backup_exit_status
if (( cleanup_failed != 0 )); then
  echo "One or more services failed to recover after backup" >&2
  if (( final_status == 0 )); then
    final_status=1
  fi
fi

if (( backup_exit_status == 0 && cleanup_failed == 0 )); then
  backup_finished_epoch=$($DATE_BIN +%s)
  metrics_tmp="$HOMELAB_BACKUP_METRICS_DIR/homelab-backup.prom.tmp"
  if {
    {
      printf 'homelab_backup_last_success_timestamp_seconds %s\n' "$backup_finished_epoch"
      printf 'homelab_backup_last_duration_seconds %s\n' "$((backup_finished_epoch - backup_started_epoch))"
    } > "$metrics_tmp" \
      && chmod 0644 "$metrics_tmp" \
      && mv -f "$metrics_tmp" "$HOMELAB_BACKUP_METRICS_DIR/homelab-backup.prom"
  }; then
    echo "Backup finished successfully at $($DATE_BIN)"
  else
    rm -f "$metrics_tmp"
    echo "Backup succeeded, but recording its success metrics failed" >&2
    final_status=1
  fi
elif (( backup_exit_status != 0 )); then
  echo "Backup failed with status $backup_exit_status at $($DATE_BIN)" >&2
fi

if [[ -n $HOMELAB_HEARTBEAT_BIN ]]; then
  heartbeat_action=fail
  ((final_status == 0)) && heartbeat_action=success
  if ! "$HOMELAB_HEARTBEAT_BIN" "$heartbeat_action"; then
    echo "Backup status was recorded locally, but its external heartbeat failed" >&2
  fi
fi

exit "$final_status"
