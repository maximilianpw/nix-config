#!/usr/bin/env bash
# Read-only DNS/TLS/HTTP preflight before declaring a new public health endpoint.
set -euo pipefail
: "${CURL_BIN:?CURL_BIN must be set}"
: "${HOMELAB_PUBLIC_URLS?HOMELAB_PUBLIC_URLS must be set}"

if (( $# > 0 )); then
  urls=("$@")
else
  read -r -a urls <<< "$HOMELAB_PUBLIC_URLS"
fi
if (( ${#urls[@]} == 0 )); then
  echo 'public ingress check: no health URLs supplied' >&2
  exit 2
fi

failures=0
for url in "${urls[@]}"; do
  # Public health URLs must not carry credentials, query strings or fragments.
  # Never quote an invalid URL or curl stderr into an operator log.
  if [[ ! $url =~ ^https://[a-z0-9.-]+(/[^@?#[:space:]]*)?$ ]]; then
    echo 'public ingress check: expected an HTTPS health URL without credentials or query/fragment' >&2
    failures=$((failures + 1))
    continue
  fi
  host=${url#https://}
  host=${host%%/*}
  if status=$("$CURL_BIN" --fail --silent --location --proto '=https' --proto-redir '=https' \
      --connect-timeout 5 --max-time 15 --output /dev/null --write-out '%{http_code}' -- "$url" 2>/dev/null) && [[ $status =~ ^2[0-9][0-9]$ ]]; then
    printf 'OK: %s public health returned HTTP %s\n' "$host" "$status"
  else
    printf 'FAIL: %s public health failed (HTTP %s; check DNS/TLS/connectivity before rollout)\n' "$host" "${status:-000}" >&2
    failures=$((failures + 1))
  fi
done
(( failures == 0 ))
