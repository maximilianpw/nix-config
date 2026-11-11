#!/usr/bin/env bash

set -eu

: "${BORG_BIN:?BORG_BIN must be set}" "${FIND_BIN:?FIND_BIN must be set}"
: "${BORG_REPO:?BORG_REPO must be set}" "${BORG_PASSCOMMAND:?BORG_PASSCOMMAND must be set}"

if [ "$(id -u)" -ne 0 ]; then
  echo "borg-restore-main must run as root so it can read the repository passphrase" >&2
  echo "Try: sudo borg-restore-main <archive> <existing-empty-directory> [path ...]" >&2
  exit 1
fi

if [ "$#" -lt 2 ]; then
  echo "Usage: borg-restore-main <archive> <existing-empty-directory> [path ...]" >&2
  echo "List archives first with: sudo borg-job-main list" >&2
  exit 2
fi

archive="$1"
destination="$2"
shift 2

if [ ! -d "$destination" ]; then
  echo "Refusing to create the restore destination; create it explicitly first: $destination" >&2
  exit 1
fi
if [ -n "$("$FIND_BIN" "$destination" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
  echo "Restore destination must be empty: $destination" >&2
  exit 1
fi

case "$archive" in
  ::*) archive_ref="$archive" ;;
  *) archive_ref="::$archive" ;;
esac

cd "$destination"
exec "$BORG_BIN" extract --list "$archive_ref" "$@"
