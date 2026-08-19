#!/usr/bin/env bash
# Build a restorable T3 Code archive without stopping the live server. SQLite's
# online backup API snapshots the database; rsync captures the remaining state.
set -euo pipefail

: "${T3CODE_SOURCE_DIR:=/home/maxpw/.local/share/t3code}"
: "${T3CODE_BACKUP_DIR:=/var/backup/t3code}"
: "${SQLITE_BIN:=sqlite3}"
: "${RSYNC_BIN:=rsync}"
: "${TAR_BIN:=tar}"

source_database="$T3CODE_SOURCE_DIR/userdata/state.sqlite"
archive="$T3CODE_BACKUP_DIR/state.tar"
archive_tmp="$archive.tmp"
umask 077
install -d -m 0700 "$T3CODE_BACKUP_DIR"
staging=$(mktemp -d "$T3CODE_BACKUP_DIR/.stage.XXXXXX")
cleanup() {
  rm -rf "$staging"
  rm -f "$archive_tmp"
}
trap cleanup EXIT

mkdir -p "$staging/userdata"
"$SQLITE_BIN" "$source_database" ".backup '$staging/userdata/state.sqlite'"
"$RSYNC_BIN" --archive --delete \
  --exclude='/userdata/state.sqlite' \
  --exclude='/userdata/state.sqlite-*' \
  "$T3CODE_SOURCE_DIR/" "$staging/"
chown --reference="$source_database" "$staging/userdata/state.sqlite"
chmod --reference="$source_database" "$staging/userdata/state.sqlite"
[[ $("$SQLITE_BIN" "$staging/userdata/state.sqlite" 'PRAGMA integrity_check;') == ok ]]
"$TAR_BIN" --create --sparse --file "$archive_tmp" --directory "$staging" .
mv -f "$archive_tmp" "$archive"
