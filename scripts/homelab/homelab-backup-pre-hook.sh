#!/usr/bin/env bash

: "${DATE_BIN:?DATE_BIN must be set}" "${FLOCK_BIN:?FLOCK_BIN must be set}"
: "${GIT_BIN:?GIT_BIN must be set}" "${JQ_BIN:?JQ_BIN must be set}"
: "${BORG_OPERATION_LOCK_FILE:?BORG_OPERATION_LOCK_FILE must be set}"
: "${NIX_CONFIG_DIR:?NIX_CONFIG_DIR must be set}"
: "${HOMELAB_MANIFEST_STATIC:?HOMELAB_MANIFEST_STATIC must be set}"
: "${HOMELAB_MANIFEST_TMP:?HOMELAB_MANIFEST_TMP must be set}"
: "${HOMELAB_MANIFEST_PATH:?HOMELAB_MANIFEST_PATH must be set}"
: "${HOMELAB_BACKUP_COORDINATOR_BIN:?HOMELAB_BACKUP_COORDINATOR_BIN must be set}"

echo "Starting backup at $($DATE_BIN)"
# Used later by Borg's postHook in the same caller shell.
# shellcheck disable=SC2034
backup_started_epoch=$($DATE_BIN +%s)
backup_started_at=$($DATE_BIN --iso-8601=seconds)

if [[ -n ${HOMELAB_HEARTBEAT_BIN:-} ]] && ! "$HOMELAB_HEARTBEAT_BIN" start; then
  echo "External backup start heartbeat failed; continuing with the local backup" >&2
fi

# Acquire this before generating artifacts or stopping applications.
# Consistency checks use the same lock, so delayed timers and manual
# starts cannot make Borg contend after services are already quiesced.
exec 9>"$BORG_OPERATION_LOCK_FILE"
"$FLOCK_BIN" 9

git_revision="$("$GIT_BIN" -c safe.directory="$NIX_CONFIG_DIR" -C "$NIX_CONFIG_DIR" rev-parse HEAD 2>/dev/null || printf unavailable)"
git_dirty=false
if [ "$git_revision" != unavailable ] && [ -n "$("$GIT_BIN" -c safe.directory="$NIX_CONFIG_DIR" -C "$NIX_CONFIG_DIR" status --porcelain 2>/dev/null)" ]; then
  git_dirty=true
fi
manifest_tmp=$HOMELAB_MANIFEST_TMP
printf '%s\n' "$HOMELAB_MANIFEST_STATIC" \
  | "$JQ_BIN" \
    --arg backupStartTimestamp "$backup_started_at" \
    --arg gitRevision "$git_revision" \
    --argjson gitDirty "$git_dirty" \
    '. + {backupStartTimestamp: $backupStartTimestamp, gitRevision: $gitRevision, gitDirty: $gitDirty}' \
  > "$manifest_tmp"
chmod 0600 "$manifest_tmp"
mv -f "$manifest_tmp" "$HOMELAB_MANIFEST_PATH"

# The coordinator persists the pre-existing active set before stopping
# anything. Its cleanup phase can therefore recover services after a
# preparation failure or Borg failure without starting units that were
# already inactive.
"$HOMELAB_BACKUP_COORDINATOR_BIN" prepare
