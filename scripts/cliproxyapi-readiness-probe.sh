#!/usr/bin/env bash

# Fixed-target readiness probe for the local CLIProxyAPI process. The Nix
# wrapper injects the destination; nothing on the command line can change it,
# and the key is sent only to a loopback URL.

set -euo pipefail

: "${CURL_BIN:?CURL_BIN must be set}"
: "${CLIPROXYAPI_MODELS_URL:?CLIPROXYAPI_MODELS_URL must be set}"
: "${HOMELAB_METRICS_DIR:?HOMELAB_METRICS_DIR must be set}"
: "${CREDENTIALS_DIRECTORY:?CREDENTIALS_DIRECTORY must be set}"

if (( $# != 0 )); then
  echo "cliproxyapi-readiness-probe accepts no arguments" >&2
  exit 2
fi

# Anchored so userinfo, extra hosts, queries, or fragments cannot smuggle a
# different destination past the loopback check.
if [[ ! $CLIPROXYAPI_MODELS_URL =~ ^http://127[.]0[.]0[.]1:([0-9]{1,5})/v1/models$ ]]; then
  echo "CLIProxyAPI readiness probe target must be http://127.0.0.1:<port>/v1/models" >&2
  exit 1
fi
target_port=$((10#${BASH_REMATCH[1]}))
if (( target_port < 1 || target_port > 65535 )); then
  echo "CLIProxyAPI readiness probe target port must be between 1 and 65535" >&2
  exit 1
fi

credential_file="$CREDENTIALS_DIRECTORY/cliproxyapi-local-api-key"
if [[ ! -r $credential_file ]]; then
  echo "CLIProxyAPI local API key credential is not readable" >&2
  exit 1
fi
api_key=$(< "$credential_file")
if [[ -z $api_key ]]; then
  echo "CLIProxyAPI local API key credential is empty" >&2
  exit 1
fi

metrics_file="${HOMELAB_METRICS_DIR}/cliproxyapi-readiness.prom"
work_dir=$(mktemp -d)
metrics_tmp=""

cleanup() {
  rm -rf "$work_dir"
  if [[ -n $metrics_tmp ]]; then
    rm -f "$metrics_tmp"
  fi
}
trap cleanup EXIT

# The header file keeps the bearer token out of curl's process arguments.
header_file="$work_dir/headers"
body_file="$work_dir/body"
(
  umask 077
  printf 'Authorization: Bearer %s\n' "$api_key" > "$header_file"
)

# --disable must come first so ~/.curlrc is ignored; --noproxy keeps proxy
# environment variables from redirecting the fixed loopback request. A
# non-zero curl exit (timeout, truncated body, connection error) is never
# ready, even when the status and partial body look right.
curl_exit=0
http_status=$("$CURL_BIN" \
  --disable \
  --silent \
  --show-error \
  --noproxy '*' \
  --max-time 10 \
  --max-redirs 0 \
  --header @"$header_file" \
  --output "$body_file" \
  --write-out '%{http_code}' \
  "$CLIPROXYAPI_MODELS_URL" 2>/dev/null) || curl_exit=$?
case $http_status in
  [0-9][0-9][0-9]) ;;
  *) http_status=000 ;;
esac

ready=0
if (( curl_exit == 0 )) && [[ $http_status == 200 && -s $body_file ]]; then
  body=$(< "$body_file")
  if [[ $body =~ \"object\"[[:space:]]*:[[:space:]]*\"list\" ]]; then
    ready=1
  fi
fi

printf -v probe_timestamp '%(%s)T' -1

metrics_tmp="$(mktemp "${metrics_file}.XXXXXX")"
{
  printf '# HELP cliproxyapi_backend_ready Whether the local CLIProxyAPI answered an authenticated model listing.\n'
  printf '# TYPE cliproxyapi_backend_ready gauge\n'
  printf 'cliproxyapi_backend_ready %s\n' "$ready"
  printf '# HELP cliproxyapi_backend_probe_http_status HTTP status of the last readiness probe, 0 when no response arrived.\n'
  printf '# TYPE cliproxyapi_backend_probe_http_status gauge\n'
  printf 'cliproxyapi_backend_probe_http_status %s\n' "$((10#$http_status))"
  printf '# HELP cliproxyapi_backend_probe_timestamp_seconds Unix time of the last readiness probe.\n'
  printf '# TYPE cliproxyapi_backend_probe_timestamp_seconds gauge\n'
  printf 'cliproxyapi_backend_probe_timestamp_seconds %s\n' "$probe_timestamp"
} > "$metrics_tmp"

chmod 0644 "$metrics_tmp"
mv -f "$metrics_tmp" "$metrics_file"
metrics_tmp=""
