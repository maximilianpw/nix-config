#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/scripts/prowlarr-reconcile.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/config.xml" <<'XML'
<Config><ApiKey>fixturekey123</ApiKey></Config>
XML

cat > "$tmp/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
config=$2
method=$(sed -n 's/^request = "\(.*\)"$/\1/p' "$config")
url=$(sed -n 's/^url = "\(.*\)"$/\1/p' "$config")
data_file=$(sed -n 's/^data-binary = "@\(.*\)"$/\1/p' "$config")
case "$method $url" in
  'GET http://127.0.0.1:9696/api/v1/system/status') printf '{}\n' ;;
  'GET http://127.0.0.1:9696/api/v1/applications')
    if [[ -f $STATE_DIR/readarr-deleted ]]; then
      printf '%s\n' '[{"id":2,"implementation":"Radarr","fields":[]},{"id":3,"implementation":"Lidarr","fields":[]}]'
    else
      printf '%s\n' '[{"id":1,"implementation":"Readarr","fields":[{"name":"baseUrl","value":"http://localhost:8787"}]},{"id":2,"implementation":"Radarr","fields":[]},{"id":3,"implementation":"Lidarr","fields":[]}]'
    fi
    ;;
  'DELETE http://127.0.0.1:9696/api/v1/applications/1') touch "$STATE_DIR/readarr-deleted" ;;
  'GET http://127.0.0.1:9696/api/v1/applications/2')
    if [[ -f $STATE_DIR/radarr.json ]]; then cat "$STATE_DIR/radarr.json"; else
      printf '%s\n' '{"id":2,"implementation":"Radarr","fields":[{"name":"syncCategories","value":[2000]}]}'
    fi
    ;;
  'GET http://127.0.0.1:9696/api/v1/applications/3')
    printf '%s\n' '{"id":3,"implementation":"Lidarr","fields":[{"name":"syncCategories","value":[3000,8000]}]}'
    ;;
  'PUT http://127.0.0.1:9696/api/v1/applications/2') cp "$data_file" "$STATE_DIR/radarr.json" ;;
  *) printf 'unexpected request: %s %s\n' "$method" "$url" >&2; exit 1 ;;
esac
EOF
chmod +x "$tmp/curl"

export STATE_DIR=$tmp
export CURL_BIN=$tmp/curl
export JQ_BIN
JQ_BIN=$(command -v jq)
export SED_BIN
SED_BIN=$(command -v sed)
export SLEEP_BIN
SLEEP_BIN=$(command -v true)
export PROWLARR_CONFIG_FILE=$tmp/config.xml

"$script" > "$tmp/first.out"
test -f "$tmp/readarr-deleted"
jq -e '.fields[] | select(.name == "syncCategories") | .value == [2000, 8000]' "$tmp/radarr.json" >/dev/null
grep -Fq 'Removed retired Readarr application 1' "$tmp/first.out"
grep -Fq 'Added category 8000 to the Radarr Prowlarr sync categories' "$tmp/first.out"

# A second run is a no-op.
"$script" > "$tmp/second.out"
test ! -s "$tmp/second.out"

echo "prowlarr reconcile tests passed"
