#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export JQ_BIN
JQ_BIN=$(command -v jq)
export TUNARR_SETTINGS_FILE=$tmp/settings.json
export FFMPEG_BIN=/fixture/ffmpeg
export FFPROBE_BIN=/fixture/ffprobe
script=$repo_root/scripts/homelab/tunarr-reconcile-settings.sh

# Fresh installations retain Tunarr's responsibility for schema defaults.
bash "$script"
jq -e '.settings.ffmpeg == {ffmpegExecutablePath: "/fixture/ffmpeg", ffprobeExecutablePath: "/fixture/ffprobe"}' "$TUNARR_SETTINGS_FILE" >/dev/null
[[ $(stat -c %a "$TUNARR_SETTINGS_FILE") == 600 ]]

# Only the two Nix-owned paths change; preserve unknown fields and migration state.
printf '%s\n' '{"version":1,"migration":{"legacyMigration":true},"settings":{"clientId":"fixture","ffmpeg":{"ffmpegExecutablePath":"/old/ffmpeg","ffprobeExecutablePath":"/old/ffprobe","enableLogging":true}},"unknown":{"keep":true}}' > "$TUNARR_SETTINGS_FILE"
bash "$script"
jq -e '.migration.legacyMigration and .unknown.keep and .settings.ffmpeg.enableLogging and .settings.clientId == "fixture" and .settings.ffmpeg.ffmpegExecutablePath == "/fixture/ffmpeg" and .settings.ffmpeg.ffprobeExecutablePath == "/fixture/ffprobe"' "$TUNARR_SETTINGS_FILE" >/dev/null
cp "$TUNARR_SETTINGS_FILE" "$tmp/expected"
bash "$script"
cmp "$TUNARR_SETTINGS_FILE" "$tmp/expected"

# Never replace a corrupt file or silently discard an unexpected structure.
for document in 'not-json' '[]' '{"settings":null}' '{"settings":{"ffmpeg":[]}}' '{} {}' ''; do
  printf '%s' "$document" > "$TUNARR_SETTINGS_FILE"
  cp "$TUNARR_SETTINGS_FILE" "$tmp/expected"
  if bash "$script" > "$tmp/out" 2> "$tmp/err"; then
    echo 'Tunarr settings reconciliation accepted malformed settings' >&2
    exit 1
  fi
  cmp "$TUNARR_SETTINGS_FILE" "$tmp/expected"
done
[[ $(find "$tmp" -name 'settings.json.*' | wc -l) == 0 ]]
echo 'Tunarr settings reconciliation tests passed'
