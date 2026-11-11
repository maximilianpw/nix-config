#!/usr/bin/env bash
# Coordinates application quiesce around Borg. State is persisted so cleanup can
# recover previously active units even when preparation or Borg fails.
#
# prepare: record active quiesce units, run `online` steps, stop the units, run
# `quiesced` steps, then restart dump-phase units. Archive-phase units stay
# stopped until cleanup. Steps come from HOMELAB_PREPARE_STEPS_FILE as
# `stage<TAB>name<TAB>command` lines in execution order.
set -euo pipefail

: "${SYSTEMCTL_BIN:?SYSTEMCTL_BIN must be set}"
: "${HOMELAB_PREPARE_STEPS_FILE:?HOMELAB_PREPARE_STEPS_FILE must be set}"
: "${HOMELAB_BACKUP_STATE_DIR:=/run/homelab-backup}"
state_file="$HOMELAB_BACKUP_STATE_DIR/active-units"

remove_from_state() {
  local phase=$1 unit=$2 temporary
  temporary="$state_file.tmp"
  awk -F '\t' -v phase="$phase" -v unit="$unit" \
    '!( $1 == phase && $2 == unit )' "$state_file" > "$temporary"
  mv -f "$temporary" "$state_file"
}

run_steps() {
  local wanted=$1 entry stage name command
  local -a steps
  mapfile -t steps < "$HOMELAB_PREPARE_STEPS_FILE"
  for entry in "${steps[@]}"; do
    IFS=$'\t' read -r stage name command <<< "$entry"
    [[ $stage == "$wanted" ]] || continue
    if ! "$command"; then
      echo "Backup preparation step $name failed" >&2
      return 1
    fi
  done
}

prepare() {
  local unit
  local -a dump_units archive_units active_dump=() active_archive=()
  read -r -a dump_units <<< "${HOMELAB_DUMP_UNITS:-}"
  read -r -a archive_units <<< "${HOMELAB_ARCHIVE_UNITS:-}"

  install -d -m 0700 "$HOMELAB_BACKUP_STATE_DIR"
  if [[ -s $state_file ]]; then
    echo "Refusing a new backup while unresolved service recovery state exists: $state_file" >&2
    echo "Run homelab-backup-coordinator cleanup and resolve every restart failure first" >&2
    return 1
  fi
  rm -f "$state_file"

  : > "$state_file.tmp"
  for unit in "${dump_units[@]}"; do
    if "$SYSTEMCTL_BIN" is-active --quiet "$unit"; then
      active_dump+=("$unit")
      printf 'dump\t%s\n' "$unit" >> "$state_file.tmp"
    fi
  done
  for unit in "${archive_units[@]}"; do
    if "$SYSTEMCTL_BIN" is-active --quiet "$unit"; then
      active_archive+=("$unit")
      printf 'archive\t%s\n' "$unit" >> "$state_file.tmp"
    fi
  done
  mv -f "$state_file.tmp" "$state_file"

  # Online steps (such as SQLite snapshots) run before any outage starts.
  run_steps online

  for unit in "${active_dump[@]}" "${active_archive[@]}"; do
    "$SYSTEMCTL_BIN" stop "$unit"
  done

  run_steps quiesced

  for unit in "${active_dump[@]}"; do
    "$SYSTEMCTL_BIN" start "$unit"
    remove_from_state dump "$unit"
  done
}

cleanup() {
  local phase unit cleanup_failed=0
  if [[ ! -f $state_file ]]; then
    return 0
  fi

  while IFS=$'\t' read -r phase unit; do
    [[ -n $unit ]] || continue
    if ! "$SYSTEMCTL_BIN" start "$unit"; then
      echo "Failed to restart $unit after backup" >&2
      cleanup_failed=1
    fi
  done < "$state_file"

  if (( cleanup_failed == 0 )); then
    rm -f "$state_file"
  fi
  return "$cleanup_failed"
}

case "${1:-}" in
  prepare) prepare ;;
  cleanup) cleanup ;;
  *)
    echo "Usage: homelab-backup-coordinator {prepare|cleanup}" >&2
    exit 2
    ;;
esac
