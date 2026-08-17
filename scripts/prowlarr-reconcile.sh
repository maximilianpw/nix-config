#!/usr/bin/env bash
# Reconcile retired integrations and category mappings that otherwise make every
# Prowlarr full-sync generate connection and validation errors.
set -euo pipefail

: "${CURL_BIN:=curl}"
: "${JQ_BIN:=jq}"
: "${SED_BIN:=sed}"
: "${SLEEP_BIN:=sleep}"
: "${PROWLARR_CONFIG_FILE:=/var/lib/prowlarr/config.xml}"
: "${PROWLARR_URL:=http://127.0.0.1:9696}"

api_key=$($SED_BIN -n 's:.*<ApiKey>\([^<]*\)</ApiKey>.*:\1:p' "$PROWLARR_CONFIG_FILE")
if [[ ! $api_key =~ ^[A-Za-z0-9]+$ ]]; then
  echo "Cannot read a valid Prowlarr API key" >&2
  exit 1
fi

request_config=$(mktemp)
payload=$(mktemp)
cleanup() {
  rm -f "$request_config" "$payload"
}
trap cleanup EXIT

api() {
  local method=$1 path=$2 data_file=${3:-}
  umask 077
  {
    printf 'silent\nshow-error\nfail-with-body\n'
    printf 'request = "%s"\n' "$method"
    printf 'url = "%s%s"\n' "$PROWLARR_URL" "$path"
    printf 'header = "X-Api-Key: %s"\n' "$api_key"
    if [[ -n $data_file ]]; then
      printf 'header = "Content-Type: application/json"\n'
      printf 'data-binary = "@%s"\n' "$data_file"
    fi
  } > "$request_config"
  "$CURL_BIN" --config "$request_config"
}

ready=0
for _attempt in {1..60}; do
  if api GET /api/v1/system/status >/dev/null 2>&1; then
    ready=1
    break
  fi
  "$SLEEP_BIN" 1
done
if ((ready == 0)); then
  echo "Prowlarr API did not become ready" >&2
  exit 1
fi

applications=$(api GET /api/v1/applications)
mapfile -t retired_ids < <(
  printf '%s' "$applications" | "$JQ_BIN" -r '
    .[]
    | select(
        .implementation == "Readarr"
        or any(.fields[]?; .name == "baseUrl" and (.value | tostring | test("^https?://(localhost|127[.]0[.]0[.]1):8787/?$")))
      )
    | .id
  '
)
for id in "${retired_ids[@]}"; do
  api DELETE "/api/v1/applications/$id" >/dev/null
  echo "Removed retired Readarr application $id from Prowlarr"
done

applications=$(api GET /api/v1/applications)
mapfile -t category_apps < <(
  printf '%s' "$applications" | "$JQ_BIN" -r '.[] | select(.implementation == "Radarr" or .implementation == "Lidarr") | [.id, .implementation] | @tsv'
)
for entry in "${category_apps[@]}"; do
  IFS=$'\t' read -r id implementation <<< "$entry"
  resource=$(api GET "/api/v1/applications/$id")
  if printf '%s' "$resource" | "$JQ_BIN" -e '
    any(.fields[]?; .name == "syncCategories" and ((.value // []) | index(8000) == null))
  ' >/dev/null; then
    printf '%s' "$resource" | "$JQ_BIN" '
      .fields |= map(if .name == "syncCategories" then .value = ((.value // []) + [8000] | unique) else . end)
    ' > "$payload"
    api PUT "/api/v1/applications/$id" "$payload" >/dev/null
    echo "Added category 8000 to the $implementation Prowlarr sync categories"
  fi
done
