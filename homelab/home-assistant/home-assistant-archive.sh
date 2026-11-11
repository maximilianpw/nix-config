#!/usr/bin/env bash
# Archive Home Assistant's quiesced config tree so Borg captures a consistent
# copy instead of the live directory.
set -euo pipefail

: "${TAR_BIN:?TAR_BIN must be set}"
: "${HOME_ASSISTANT_SOURCE_DIR:?HOME_ASSISTANT_SOURCE_DIR must be set}"
: "${HOME_ASSISTANT_ARCHIVE:?HOME_ASSISTANT_ARCHIVE must be set}"

install -d -m 0700 "$(dirname "$HOME_ASSISTANT_ARCHIVE")"
rm -f "$HOME_ASSISTANT_ARCHIVE.tmp"
"$TAR_BIN" --create --sparse --file "$HOME_ASSISTANT_ARCHIVE.tmp" \
  --directory "$(dirname "$HOME_ASSISTANT_SOURCE_DIR")" "$(basename "$HOME_ASSISTANT_SOURCE_DIR")"
chmod 0600 "$HOME_ASSISTANT_ARCHIVE.tmp"
mv -f "$HOME_ASSISTANT_ARCHIVE.tmp" "$HOME_ASSISTANT_ARCHIVE"
