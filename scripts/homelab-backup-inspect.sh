#!/usr/bin/env bash
# Read-only Borg archive inspection. This command never extracts into live paths.
set -euo pipefail

: "${BORG_BIN:=borg}"
: "${JQ_BIN:=jq}"
: "${TAR_BIN:=tar}"

usage() {
  cat >&2 <<'EOF'
Usage: homelab-backup-inspect [archive]

Without an archive, list repository archives. With an archive, print its
recovery manifest, verify required members, validate the Home Assistant tar,
and list PostgreSQL dump files. No restore is performed.
EOF
}

if [[ ${HOMELAB_REQUIRE_ROOT:-0} == 1 && $(id -u) -ne 0 ]]; then
  echo "homelab-backup-inspect must run as root so it can read the Borg passphrase" >&2
  exit 1
fi

if (( $# > 1 )); then
  usage
  exit 2
fi

if (( $# == 0 )); then
  "$BORG_BIN" list --json \
    | "$JQ_BIN" -r '.archives[] | [.name, .start, .id] | @tsv'
  exit 0
fi

archive=$1
case "$archive" in
  ::*) archive_ref=$archive ;;
  *) archive_ref="::$archive" ;;
esac

listing=$(mktemp)
paths=$(mktemp)
ha_tar=$(mktemp)
manifest=$(mktemp)
cleanup() {
  rm -f "$listing" "$paths" "$ha_tar" "$manifest"
}
trap cleanup EXIT

"$BORG_BIN" list --json-lines "$archive_ref" > "$listing"
"$JQ_BIN" -r '.path' "$listing" > "$paths"

printf '%s\n' 'Archive metadata:'
"$BORG_BIN" info --json "$archive_ref" | "$JQ_BIN" '.archives[0] // {}'
printf '%s\n' 'Recovery manifest:'
"$BORG_BIN" extract --stdout "$archive_ref" var/backup/homelab/manifest.json > "$manifest"
"$JQ_BIN" -e '
  .schemaVersion == 1
  and (.expectedArchivePaths | type == "array" and length > 0)
  and all(.expectedArchivePaths[]; type == "string" and startswith("/"))
' "$manifest" >/dev/null
"$JQ_BIN" . "$manifest"

mapfile -t required_paths < <("$JQ_BIN" -r '.expectedArchivePaths[] | ltrimstr("/")' "$manifest")
missing=0
for required in "${required_paths[@]}"; do
  if ! awk -v path="$required" '$0 == path || index($0, path "/") == 1 { found = 1; exit } END { exit !found }' "$paths"; then
    printf 'MISSING: %s\n' "$required" >&2
    missing=1
  fi
done

if grep -Fxq 'var/backup/home-assistant/config.tar' "$paths"; then
  "$BORG_BIN" extract --stdout "$archive_ref" var/backup/home-assistant/config.tar > "$ha_tar"
  if ! "$TAR_BIN" -tf "$ha_tar" | awk '$0 == "hass" || index($0, "hass/") == 1 { found = 1 } END { exit !found }'; then
    echo "INVALID: Home Assistant archive does not contain the hass tree" >&2
    missing=1
  fi
fi

printf '%s\n' 'PostgreSQL dump files:'
if ! awk '/^var\/backup\/postgresql\// && $0 !~ /\/$/ { print; found = 1 } END { exit !found }' "$paths"; then
  echo "MISSING: no PostgreSQL dump files found" >&2
  missing=1
fi

if (( missing != 0 )); then
  echo "Archive inspection failed; no files were restored" >&2
  exit 1
fi

echo "Archive inspection passed; no files were restored"
