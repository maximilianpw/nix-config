#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/tests/portable-gnu-fixtures.sh
source "$script_dir/tests/portable-gnu-fixtures.sh"
test_root="$(mktemp -d)"
server_pid=""
cleanup() {
  if [[ -n $server_pid ]]; then
    kill "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$test_root"
}
trap cleanup EXIT

metrics_dir="$test_root/metrics"
credentials_dir="$test_root/credentials"
request_log="$test_root/requests.log"
curl_arguments_log="$test_root/curl-arguments.log"
mode_file="$test_root/mode"
port_file="$test_root/port"
recording_curl="$test_root/curl"
fixture_server="$test_root/server.py"
metrics_file="$metrics_dir/cliproxyapi-readiness.prom"
mkdir -p "$metrics_dir" "$credentials_dir"
: > "$request_log"
printf 'ok' > "$mode_file"
printf '%s' 'local-test-key-123' > "$credentials_dir/cliproxyapi-local-api-key"

# A loopback HTTP fixture that records the Authorization header it receives
# and answers according to the mode file. The truncated mode advertises more
# body than it sends so curl reports a partial transfer.
cat > "$fixture_server" <<'EOF'
import http.server
import os

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        with open(os.environ["FIXTURE_REQUEST_LOG"], "a", encoding="utf-8") as log:
            log.write(f"{self.path}\t{self.headers.get('Authorization', '')}\n")
        with open(os.environ["FIXTURE_MODE_FILE"], encoding="utf-8") as handle:
            mode = handle.read().strip()
        if mode == "ok":
            status, body = 200, b'{"object": "list", "data": [{"id": "gpt-5.6-sol", "object": "model"}]}'
        elif mode == "unauthorized":
            status, body = 401, b'{"error": {"message": "unauthorized", "type": "invalid_request_error"}}'
        elif mode == "truncated":
            status, body = 200, b'{"object": "list", "data": [{"id": "gpt-5.6-sol"'
        else:
            status, body = 200, b'<html><body>management ui</body></html>'
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body) + (4096 if mode == "truncated" else 0)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)
        self.wfile.flush()

    def log_message(self, *args):
        pass

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(os.environ["FIXTURE_PORT_FILE"], "w", encoding="utf-8") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
EOF

# The real curl (from the dev shell) performs the request; this wrapper only
# records every process argument so the test can prove the key is not there.
real_curl=$(command -v curl || true)
if [[ -z $real_curl ]]; then
  echo "curl not on PATH; run inside 'nix develop'" >&2
  exit 1
fi
cat > "$recording_curl" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\\n' "\$@" >> "$curl_arguments_log"
exec "$real_curl" "\$@"
EOF
chmod +x "$recording_curl"

FIXTURE_REQUEST_LOG="$request_log" FIXTURE_MODE_FILE="$mode_file" FIXTURE_PORT_FILE="$port_file" \
  python3 "$fixture_server" &
server_pid=$!
for _ in $(seq 1 100); do
  [[ -s $port_file ]] && break
  sleep 0.05
done
[[ -s $port_file ]] || { echo "fixture server did not start" >&2; exit 1; }
port=$(< "$port_file")
models_url="http://127.0.0.1:${port}/v1/models"

run_probe() {
  CURL_BIN="$recording_curl" \
    CLIPROXYAPI_MODELS_URL="${PROBE_URL:-$models_url}" \
    HOMELAB_METRICS_DIR="$metrics_dir" \
    CREDENTIALS_DIRECTORY="${PROBE_CREDENTIALS_DIRECTORY:-$credentials_dir}" \
    "$script_dir/cliproxyapi-readiness-probe.sh" "$@"
}

assert_metric() {
  local line=$1
  grep -Fxq -- "$line" "$metrics_file" || {
    echo "expected '$line' in:" >&2
    cat "$metrics_file" >&2
    exit 1
  }
}

assert_request_count() {
  local expected=$1 actual
  actual=$(wc -l < "$request_log" | tr -d ' ')
  [[ $actual == "$expected" ]] || {
    echo "expected $expected requests to reach the fixture, saw $actual" >&2
    exit 1
  }
}

# Valid authenticated model listing: ready, timestamp, atomic 0644 file, and
# the key reaches the server through the header file rather than argv.
run_probe
assert_metric 'cliproxyapi_backend_ready 1'
assert_metric 'cliproxyapi_backend_probe_http_status 200'
grep -Eq -- '^cliproxyapi_backend_probe_timestamp_seconds [0-9]+$' "$metrics_file"
assert_file_mode "$metrics_file" 0644
test -z "$(find "$metrics_dir" -type f ! -name 'cliproxyapi-readiness.prom' -print -quit)"
assert_request_count 1
grep -Fxq -- $'/v1/models\tBearer local-test-key-123' "$request_log"
if grep -Fq -- 'local-test-key-123' "$curl_arguments_log"; then
  echo "API key leaked into curl process arguments" >&2
  exit 1
fi
[[ "$(head -n 1 "$curl_arguments_log")" == '--disable' ]]
grep -Fxq -- '--noproxy' "$curl_arguments_log"
grep -Fxq -- '--max-redirs' "$curl_arguments_log"

# HTTP 401 from the backend means the key did not load: not ready.
printf 'unauthorized' > "$mode_file"
run_probe
assert_metric 'cliproxyapi_backend_ready 0'
assert_metric 'cliproxyapi_backend_probe_http_status 401'
assert_request_count 2

# A 200 that is not a model listing (for example the management UI): not ready.
printf 'wrong-body' > "$mode_file"
run_probe
assert_metric 'cliproxyapi_backend_ready 0'
assert_request_count 3

# A 200 whose body starts like a listing but is cut off: curl exits non-zero
# and the probe must not report ready even though the status was 200.
printf 'truncated' > "$mode_file"
run_probe
assert_metric 'cliproxyapi_backend_ready 0'
assert_metric 'cliproxyapi_backend_probe_http_status 200'
assert_request_count 4

# Missing or empty credential: fail without sending a request or touching the file.
printf 'ok' > "$mode_file"
empty_credentials_dir="$test_root/empty-credentials"
mkdir -p "$empty_credentials_dir"
: > "$empty_credentials_dir/cliproxyapi-local-api-key"
before=$(cat "$metrics_file")
for bad_credentials_dir in "$test_root/missing" "$empty_credentials_dir"; do
  if PROBE_CREDENTIALS_DIRECTORY="$bad_credentials_dir" run_probe >/dev/null 2>&1; then
    echo "probe unexpectedly ran with credentials from $bad_credentials_dir" >&2
    exit 1
  fi
done
assert_request_count 4
[[ "$(cat "$metrics_file")" == "$before" ]]

# The destination is fixed: arguments are rejected and anything that is not
# exactly http://127.0.0.1:<port>/v1/models never receives the key.
if run_probe "$models_url" >/dev/null 2>&1; then
  echo "probe unexpectedly accepted a positional target" >&2
  exit 1
fi
bad_urls=(
  "http://10.0.0.5:${port}/v1/models"
  "https://cliproxy.example/v1/models"
  "http://127.0.0.1:${port}/v1/chat/completions"
  "http://127.0.0.1:${port}@127.0.0.2:9999/v1/models"
  "http://user:pass@127.0.0.1:${port}/v1/models"
  "http://127.0.0.1:${port}/v1/models?x=1"
  "http://127.0.0.1:${port}/v1/models#frag"
  "http://127.0.0.1:${port}/v1/models/"
  "http://127.0.0.1:/v1/models"
  "http://127.0.0.1/v1/models"
  "http://127.0.0.1:0/v1/models"
  "http://127.0.0.1:70000/v1/models"
  "http://127.0.0.1:${port}/v1/models http://127.0.0.2:9999/"
  "http://127.0.0.10:${port}/v1/models"
)
for bad_url in "${bad_urls[@]}"; do
  if PROBE_URL="$bad_url" run_probe >/dev/null 2>&1; then
    echo "probe unexpectedly accepted target $bad_url" >&2
    exit 1
  fi
done
assert_request_count 4

# Backend down: the file still refreshes, reporting not ready and status 0.
kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=""
run_probe
assert_metric 'cliproxyapi_backend_ready 0'
assert_metric 'cliproxyapi_backend_probe_http_status 0'

echo "cliproxyapi readiness probe tests passed"
