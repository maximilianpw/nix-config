#!/usr/bin/env bash

set -euo pipefail

: "${CURL_BIN:=curl}"
: "${HOMELAB_HEALTHCHECK_URL_FILE:=}"

if (( $# != 1 )); then
  echo "Usage: healthcheck-ping <start|success|fail>" >&2
  exit 2
fi

case $1 in
  start | success | fail) action=$1 ;;
  *)
    echo "Unknown healthcheck action: $1" >&2
    exit 2
    ;;
esac

if [[ -z $HOMELAB_HEALTHCHECK_URL_FILE || ! -r $HOMELAB_HEALTHCHECK_URL_FILE ]]; then
  echo "Healthcheck URL file is not readable" >&2
  exit 1
fi

base_url=$(< "$HOMELAB_HEALTHCHECK_URL_FILE")
base_url=${base_url%/}
case $base_url in
  https://*) ;;
  http://*)
    if [[ ${HOMELAB_HEALTHCHECK_ALLOW_HTTP:-0} != 1 ]]; then
      echo "Healthcheck URL must use HTTPS" >&2
      exit 1
    fi
    ;;
  *)
    echo "Healthcheck URL must be an HTTP(S) URL" >&2
    exit 1
    ;;
esac

case $action in
  start) target_url="$base_url/start" ;;
  success) target_url=$base_url ;;
  fail) target_url="$base_url/fail" ;;
esac

# Keep the secret token out of curl's process arguments. Curl accepts a config
# on stdin, so only the calling process ever holds the complete ping URL.
curl_config_url=${target_url//\\/\\\\}
curl_config_url=${curl_config_url//\"/\\\"}
printf 'url = "%s"\n' "$curl_config_url" | \
  "$CURL_BIN" --config - --fail --silent --show-error --max-time 10 --retry 2 --request POST >/dev/null
