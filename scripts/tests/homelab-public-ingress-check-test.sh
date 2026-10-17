#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
printf '#!%s\n' "$(command -v bash)" > "$fixture/curl"
cat >> "$fixture/curl" <<'EOF'
set -euo pipefail
[[ "$*" == *'--connect-timeout 5 --max-time 15'* ]]
[[ "$*" == *'--proto =https --proto-redir =https'* ]]
url="${!#}"
case "$url" in
  https://healthy.example.invalid/health) printf '200' ;;
  https://missing.example.invalid/health) printf '000'; exit 6 ;;
  https://broken.example.invalid/health) printf '404'; exit 22 ;;
  https://redirect.example.invalid/health) printf '301' ;;
  *) echo 'unexpected fixture URL' >&2; exit 1 ;;
esac
EOF
chmod +x "$fixture/curl"
export CURL_BIN="$fixture/curl"
export HOMELAB_PUBLIC_URLS='https://healthy.example.invalid/health'
bash "$script_dir/homelab-public-ingress-check.sh" > "$fixture/output"
grep -F 'OK: healthy.example.invalid' "$fixture/output"
export HOMELAB_PUBLIC_URLS='https://missing.example.invalid/health https://broken.example.invalid/health https://redirect.example.invalid/health'
if bash "$script_dir/homelab-public-ingress-check.sh" >"$fixture/output" 2>&1; then
  echo 'public preflight accepted unresolved/unhealthy endpoints' >&2
  exit 1
fi
grep -F 'FAIL: missing.example.invalid' "$fixture/output"
grep -F 'FAIL: broken.example.invalid' "$fixture/output"
grep -F 'FAIL: redirect.example.invalid' "$fixture/output"
# An explicit URL lets the operator preflight a not-yet-declared endpoint.
bash "$script_dir/homelab-public-ingress-check.sh" 'https://healthy.example.invalid/health' > /dev/null
for url in 'http://healthy.example.invalid/health' 'https://user:private@example.invalid/health' 'https://example.invalid/health?token=private'; do
  if bash "$script_dir/homelab-public-ingress-check.sh" "$url" >"$fixture/output" 2>&1; then
    echo 'public preflight accepted an insecure or credential-bearing URL' >&2
    exit 1
  fi
  ! grep -q private "$fixture/output"
done
echo 'public ingress preflight tests passed'
