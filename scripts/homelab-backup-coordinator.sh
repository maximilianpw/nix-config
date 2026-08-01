#!/usr/bin/env bash
# Coordinates application quiesce around Borg. State is persisted so cleanup can
# recover previously active units even when preparation or Borg fails.
set -euo pipefail

: "${SYSTEMCTL_BIN:=systemctl}"
: "${TAR_BIN:=tar}"
: "${SLEEP_BIN:=sleep}"
: "${HOMELAB_POSTGRESQL_BACKUP_UNIT:=postgresqlBackup.service}"
: "${HOMELAB_BACKUP_STATE_DIR:=/run/homelab-backup}"
: "${HOME_ASSISTANT_SOURCE_DIR:=/var/lib}"
: "${HOME_ASSISTANT_ARCHIVE_DIR:=/var/backup/home-assistant}"
: "${NEXTCLOUD_UPDATE_MAX_WAITS:=360}"
state_file="$HOMELAB_BACKUP_STATE_DIR/active-units"

remove_from_state() {
  local phase=$1 scope=$2 user=$3 unit=$4 temporary
  temporary="$state_file.tmp"
  awk -F '\t' -v phase="$phase" -v scope="$scope" -v user="$user" -v unit="$unit" \
    '!( $1 == phase && $2 == scope && $3 == user && $4 == unit )' "$state_file" > "$temporary"
  mv -f "$temporary" "$state_file"
}

unit_is_active() {
  local scope=$1 user=$2 unit=$3
  if [[ $scope == user ]]; then
    "$SYSTEMCTL_BIN" --user --machine="${user}@.host" is-active --quiet "$unit"
  else
    "$SYSTEMCTL_BIN" is-active --quiet "$unit"
  fi
}

require_user_manager() {
  local user=$1

  if ! "$SYSTEMCTL_BIN" --user --machine="${user}@.host" list-units --no-legend >/dev/null; then
    echo "Cannot reach the user systemd manager for $user; refusing a hot backup of user state" >&2
    return 1
  fi
}

unit_action() {
  local action=$1 scope=$2 user=$3 unit=$4
  if [[ $scope == user ]]; then
    "$SYSTEMCTL_BIN" --user --machine="${user}@.host" "$action" "$unit"
  else
    "$SYSTEMCTL_BIN" "$action" "$unit"
  fi
}

prepare() {
  local entry scope unit user waits home_assistant_archive
  local -A checked_user_managers=()
  local -a dump_units archive_units user_dump_units user_archive_units active_dump=() active_archive=()
  read -r -a dump_units <<< "${HOMELAB_DUMP_UNITS:-}"
  read -r -a archive_units <<< "${HOMELAB_ARCHIVE_UNITS:-}"
  read -r -a user_dump_units <<< "${HOMELAB_USER_DUMP_UNITS:-}"
  read -r -a user_archive_units <<< "${HOMELAB_USER_ARCHIVE_UNITS:-}"

  install -d -m 0700 "$HOMELAB_BACKUP_STATE_DIR"
  if [[ -s $state_file ]]; then
    echo "Refusing a new backup while unresolved service recovery state exists: $state_file" >&2
    echo "Run homelab-backup-coordinator cleanup and resolve every restart failure first" >&2
    return 1
  fi
  rm -f "$state_file"

  for entry in "${user_dump_units[@]}" "${user_archive_units[@]}"; do
    user=${entry%%:*}
    if [[ -z ${checked_user_managers[$user]+x} ]]; then
      require_user_manager "$user"
      checked_user_managers["$user"]=1
    fi
  done

  : > "$state_file.tmp"
  for unit in "${dump_units[@]}"; do
    if unit_is_active system - "$unit"; then
      active_dump+=("system"$'\t'"-"$'\t'"$unit")
      printf 'dump\tsystem\t-\t%s\n' "$unit" >> "$state_file.tmp"
    fi
  done
  for entry in "${user_dump_units[@]}"; do
    user=${entry%%:*}
    unit=${entry#*:}
    if unit_is_active user "$user" "$unit"; then
      active_dump+=("user"$'\t'"$user"$'\t'"$unit")
      printf 'dump\tuser\t%s\t%s\n' "$user" "$unit" >> "$state_file.tmp"
    fi
  done
  for unit in "${archive_units[@]}"; do
    if unit_is_active system - "$unit"; then
      active_archive+=("system"$'\t'"-"$'\t'"$unit")
      printf 'archive\tsystem\t-\t%s\n' "$unit" >> "$state_file.tmp"
    fi
  done
  for entry in "${user_archive_units[@]}"; do
    user=${entry%%:*}
    unit=${entry#*:}
    if unit_is_active user "$user" "$unit"; then
      active_archive+=("user"$'\t'"$user"$'\t'"$unit")
      printf 'archive\tuser\t%s\t%s\n' "$user" "$unit" >> "$state_file.tmp"
    fi
  done
  mv -f "$state_file.tmp" "$state_file"

  for entry in "${active_dump[@]}"; do
    IFS=$'\t' read -r scope user unit <<< "$entry"
    unit_action stop "$scope" "$user" "$unit"
  done
  for entry in "${active_archive[@]}"; do
    IFS=$'\t' read -r scope user unit <<< "$entry"
    unit_action stop "$scope" "$user" "$unit"
  done

  waits=0
  while "$SYSTEMCTL_BIN" is-active --quiet nextcloud-update-store-apps.service; do
    if (( waits >= NEXTCLOUD_UPDATE_MAX_WAITS )); then
      echo "Timed out waiting for the mutable Nextcloud app update to finish" >&2
      return 1
    fi
    "$SLEEP_BIN" 5
    waits=$((waits + 1))
  done

  "$SYSTEMCTL_BIN" start paperless-exporter.service

  install -d -m 0700 "$HOME_ASSISTANT_ARCHIVE_DIR"
  home_assistant_archive="$HOME_ASSISTANT_ARCHIVE_DIR/config.tar"
  rm -f "$home_assistant_archive.tmp"
  "$TAR_BIN" --create --sparse --file "$home_assistant_archive.tmp" \
    --directory "$HOME_ASSISTANT_SOURCE_DIR" hass
  chmod 0600 "$home_assistant_archive.tmp"
  mv -f "$home_assistant_archive.tmp" "$home_assistant_archive"

  "$SYSTEMCTL_BIN" start "$HOMELAB_POSTGRESQL_BACKUP_UNIT"

  for entry in "${active_dump[@]}"; do
    IFS=$'\t' read -r scope user unit <<< "$entry"
    unit_action start "$scope" "$user" "$unit"
    remove_from_state dump "$scope" "$user" "$unit"
  done
}

cleanup() {
  local phase scope user unit cleanup_failed=0
  if [[ ! -f $state_file ]]; then
    return 0
  fi

  while IFS=$'\t' read -r phase scope user unit; do
    [[ -n $unit ]] || continue
    if ! unit_action start "$scope" "$user" "$unit"; then
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
