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
mode_file="$test_root/mode"
port_file="$test_root/port"
fake_curl="$test_root/curl"
fixture_server="$test_root/server.py"
mkdir -p "$metrics_dir" "$credentials_dir"
: > "$request_log"
printf 'ok' > "$mode_file"
printf '%s' 'local-test-key-123' > "$credentials_dir/cliproxyapi-local-api-key"

# A loopback HTTP fixture that records the Authorization header it receives
# and answers according to the mode file.
cat > "$fixture_server" <<'EOF'
import http.server
import os
import sys

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
        else:
            status, body = 200, b'<html><body>management ui</body></html>'
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(os.environ["FIXTURE_PORT_FILE"], "w", encoding="utf-8") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
EOF

# curl is not part of the dev shell, so stand in for the subset the probe uses
# with a real HTTP round trip and a record of every process argument.
cat > "$fake_curl" <<'EOF'
#!/usr/bin/env python3
import sys
import urllib.error
import urllib.request

with open(sys.argv[0] + ".arguments", "a", encoding="utf-8") as log:
    log.write("\n".join(sys.argv[1:]) + "\n")

arguments = sys.argv[1:]
headers = {}
output = None
write_out = None
url = None
index = 0
while index < len(arguments):
    argument = arguments[index]
    if argument in {"--silent", "--show-error"}:
        index += 1
    elif argument in {"--max-time", "--max-redirs"}:
        index += 2
    elif argument == "--header":
        value = arguments[index + 1]
        assert value.startswith("@"), "probe must pass headers through a file"
        with open(value[1:], encoding="utf-8") as handle:
            for line in handle:
                name, _, header_value = line.rstrip("\n").partition(": ")
                headers[name] = header_value
        index += 2
    elif argument == "--output":
        output = arguments[index + 1]
        index += 2
    elif argument == "--write-out":
        write_out = arguments[index + 1]
        index += 2
    elif argument.startswith("-"):
        raise SystemExit(f"unsupported curl argument {argument}")
    else:
        assert url is None, "probe must request exactly one URL"
        url = argument
        index += 1

assert url is not None and output is not None and write_out == "%{http_code}"
request = urllib.request.Request(url, headers=headers)
status = 0
exit_code = 0
try:
    with urllib.request.urlopen(request, timeout=5) as response:
        status = response.status
        body = response.read()
except urllib.error.HTTPError as error:
    status = error.code
    body = error.read()
except urllib.error.URLError:
    body = b""
    exit_code = 7
with open(output, "wb") as handle:
    handle.write(body)
sys.stdout.write(f"{status:03d}")
raise SystemExit(exit_code)
EOF
chmod +x "$fake_curl"

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
metrics_file="$metrics_dir/cliproxyapi-readiness.prom"

run_probe() {
  CURL_BIN="$fake_curl" \
    CLIPROXYAPI_MODELS_URL="${PROBE_URL:-$models_url}" \
    HOMELAB_METRICS_DIR="$metrics_dir" \
    CREDENTIALS_DIRECTORY="${PROBE_CREDENTIALS_DIRECTORY:-$credentials_dir}" \
    "$script_dir/cliproxyapi-readiness-probe.sh" "$@"
}

assert_ready_value() {
  local expected=$1
  grep -Fxq -- "cliproxyapi_backend_ready $expected" "$metrics_file" || {
    echo "expected cliproxyapi_backend_ready $expected in:" >&2
    cat "$metrics_file" >&2
    exit 1
  }
}

request_count() {
  wc -l < "$request_log" | tr -d ' '
}

# Valid authenticated model listing: ready, timestamp, atomic 0644 file.
run_probe
assert_ready_value 1
grep -Eq -- '^cliproxyapi_backend_probe_timestamp_seconds [0-9]+$' "$metrics_file"
grep -Fxq -- 'cliproxyapi_backend_probe_http_status 200' "$metrics_file"
assert_file_mode "$metrics_file" 0644
test -z "$(find "$metrics_dir" -type f ! -name 'cliproxyapi-readiness.prom' -print -quit)"
[[ "$(request_count)" == 1 ]]
grep -Fxq -- $'/v1/models\tBearer local-test-key-123' "$request_log"
if grep -Fq -- 'local-test-key-123' "$fake_curl.arguments"; then
  echo "API key leaked into curl process arguments" >&2
  exit 1
fi
grep -Fxq -- '--max-redirs' "$fake_curl.arguments"

# HTTP 401 from the backend means the key did not load: not ready.
printf 'unauthorized' > "$mode_file"
run_probe
assert_ready_value 0
grep -Fxq -- 'cliproxyapi_backend_probe_http_status 401' "$metrics_file"
[[ "$(request_count)" == 2 ]]

# A 200 that is not a model listing (for example the management UI): not ready.
printf 'wrong-body' > "$mode_file"
run_probe
assert_ready_value 0
[[ "$(request_count)" == 3 ]]

# Missing credential: fail without sending a request or touching the file.
printf 'ok' > "$mode_file"
before=$(cat "$metrics_file")
if PROBE_CREDENTIALS_DIRECTORY="$test_root/missing" run_probe >/dev/null 2>&1; then
  echo "probe unexpectedly ran without a credential" >&2
  exit 1
fi
[[ "$(request_count)" == 3 ]]
[[ "$(cat "$metrics_file")" == "$before" ]]

# Empty credential: same treatment as a missing one.
empty_dir="$test_root/empty-credentials"
mkdir -p "$empty_dir"
: > "$empty_dir/cliproxyapi-local-api-key"
if PROBE_CREDENTIALS_DIRECTORY="$empty_dir" run_probe >/dev/null 2>&1; then
  echo "probe unexpectedly ran with an empty credential" >&2
  exit 1
fi
[[ "$(request_count)" == 3 ]]

# The destination is fixed: arguments are rejected and non-loopback or
# non-models targets never receive the key.
if run_probe "http://127.0.0.1:${port}/v1/models" >/dev/null 2>&1; then
  echo "probe unexpectedly accepted a positional target" >&2
  exit 1
fi
for bad_url in "http://10.0.0.5:${port}/v1/models" "https://cliproxy.example/v1/models" "http://127.0.0.1:${port}/v1/chat/completions"; do
  if PROBE_URL="$bad_url" run_probe >/dev/null 2>&1; then
    echo "probe unexpectedly accepted target $bad_url" >&2
    exit 1
  fi
done
[[ "$(request_count)" == 3 ]]

# Backend down: the file still refreshes, reporting not ready and status 0.
kill "$server_pid"
wait "$server_pid" 2>/dev/null || true
server_pid=""
run_probe
assert_ready_value 0
grep -Fxq -- 'cliproxyapi_backend_probe_http_status 0' "$metrics_file"

echo "cliproxyapi readiness probe tests passed"
