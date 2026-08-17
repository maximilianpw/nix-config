#!/usr/bin/env bash
# Convert the legacy Syncthing TCP probe into an HTTP health probe. A plain TCP
# connect to Syncthing's TLS transport succeeds but emits a warning every minute.
set -euo pipefail

: "${SQLITE_BIN:=sqlite3}"
: "${UPTIME_KUMA_DB:=/var/lib/uptime-kuma/kuma.db}"
: "${SYNCTHING_HEALTH_URL:=http://127.0.0.1:19384/rest/noauth/health}"

if [[ ! -f $UPTIME_KUMA_DB ]]; then
  exit 0
fi

legacy_where="type = 'port' AND hostname IN ('127.0.0.1', 'localhost') AND port = 22000"
legacy_count=$($SQLITE_BIN "$UPTIME_KUMA_DB" "SELECT count(*) FROM monitor WHERE $legacy_where;")
case $legacy_count in
  0) exit 0 ;;
  1) ;;
  *)
    echo "Refusing to rewrite $legacy_count Syncthing TCP monitors; expected at most one" >&2
    exit 1
    ;;
esac

backup_path="${UPTIME_KUMA_DB}.pre-syncthing-http-monitor"
if [[ ! -e $backup_path ]]; then
  $SQLITE_BIN "$UPTIME_KUMA_DB" ".backup '$backup_path'"
  chmod 0600 "$backup_path"
fi

escaped_url=${SYNCTHING_HEALTH_URL//\'/\'\'}
$SQLITE_BIN "$UPTIME_KUMA_DB" \
  "BEGIN IMMEDIATE; UPDATE monitor SET type = 'http', url = '$escaped_url', hostname = NULL, port = NULL WHERE $legacy_where; COMMIT;"

echo "Converted the Syncthing Uptime Kuma monitor from TCP to HTTP health probing"
