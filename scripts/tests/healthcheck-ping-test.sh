#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_curl="$test_root/curl"
url_file="$test_root/url"
arguments_file="$test_root/arguments"
config_file="$test_root/config"

cat > "$fake_curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$ARGUMENTS_FILE"
cat > "$CONFIG_FILE"
EOF
chmod +x "$fake_curl"
printf '%s\n' 'https://hc-ping.example/secret/' > "$url_file"

for action in start success fail; do
  ARGUMENTS_FILE="$arguments_file" CONFIG_FILE="$config_file" CURL_BIN="$fake_curl" HOMELAB_HEALTHCHECK_URL_FILE="$url_file" \
    "$script_dir/healthcheck-ping.sh" "$action"
  case $action in
    start) expected='https://hc-ping.example/secret/start' ;;
    success) expected='https://hc-ping.example/secret' ;;
    fail) expected='https://hc-ping.example/secret/fail' ;;
  esac
  grep -Fxq -- 'url = "'"$expected"'"' "$config_file"
  if grep -Fq -- 'hc-ping.example' "$arguments_file"; then
    echo "healthcheck URL leaked into curl process arguments" >&2
    exit 1
  fi
done

# sops-nix secret files are not required to end in a newline.
printf '%s' 'https://hc-ping.example/no-newline' > "$url_file"
ARGUMENTS_FILE="$arguments_file" CONFIG_FILE="$config_file" CURL_BIN="$fake_curl" \
  HOMELAB_HEALTHCHECK_URL_FILE="$url_file" "$script_dir/healthcheck-ping.sh" success
grep -Fxq -- 'url = "https://hc-ping.example/no-newline"' "$config_file"

printf '%s\n' 'http://hc-ping.example/secret' > "$url_file"
if CURL_BIN="$fake_curl" HOMELAB_HEALTHCHECK_URL_FILE="$url_file" \
  "$script_dir/healthcheck-ping.sh" success >/dev/null 2>&1; then
  echo "healthcheck ping unexpectedly accepted plaintext HTTP" >&2
  exit 1
fi

if CURL_BIN="$fake_curl" HOMELAB_HEALTHCHECK_URL_FILE="$test_root/missing" \
  "$script_dir/healthcheck-ping.sh" success >/dev/null 2>&1; then
  echo "healthcheck ping unexpectedly accepted a missing URL file" >&2
  exit 1
fi

echo "healthcheck ping tests passed"
