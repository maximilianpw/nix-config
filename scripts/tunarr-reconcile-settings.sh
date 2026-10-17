#!/usr/bin/env bash
# Run only before Tunarr starts: the application must not write settings concurrently.
set -euo pipefail

: "${JQ_BIN:?JQ_BIN must be set}"
: "${TUNARR_SETTINGS_FILE:?TUNARR_SETTINGS_FILE must be set}"
: "${FFMPEG_BIN:?FFMPEG_BIN must be set}"
: "${FFPROBE_BIN:?FFPROBE_BIN must be set}"

umask 077
tmp=$(mktemp "${TUNARR_SETTINGS_FILE}.XXXXXX")
trap 'rm -f "$tmp"' EXIT

# Tunarr merges a fresh, partial settings document with its schema defaults.
# Do not invoke `tunarr settings update`: 2026.10.3 writes successfully but
# leaves the process alive, preventing ExecStartPre from completing.
source_file=$TUNARR_SETTINGS_FILE
if [[ ! -e $source_file ]]; then
  printf '{}\n' > "$tmp"
  source_file=$tmp
fi

# Read before writing so the fresh-file case can use the same scratch file.
settings=$(
  "$JQ_BIN" --slurp --exit-status --arg ffmpeg "$FFMPEG_BIN" --arg ffprobe "$FFPROBE_BIN" '
    if length != 1 then error("Tunarr settings must contain one JSON document") else .[0] end
    | if type != "object" then error("Tunarr settings must be an object") else . end
    | if has("settings") and (.settings | type) != "object"
      then error("Tunarr settings section must be an object") else . end
    | if (.settings | has("ffmpeg")) and (.settings.ffmpeg | type) != "object"
      then error("Tunarr ffmpeg section must be an object") else . end
    | .settings.ffmpeg.ffmpegExecutablePath = $ffmpeg
    | .settings.ffmpeg.ffprobeExecutablePath = $ffprobe
  ' "$source_file"
)
printf '%s\n' "$settings" > "$tmp"
mv -f "$tmp" "$TUNARR_SETTINGS_FILE"
