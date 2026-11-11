#!/usr/bin/env bash
# Wait for a unit to finish instead of stopping it mid-write. Fails after
# WAIT_MAX_ATTEMPTS polls so a stuck unit cannot hold a backup open forever.
set -euo pipefail

: "${SYSTEMCTL_BIN:?SYSTEMCTL_BIN must be set}"
: "${SLEEP_BIN:?SLEEP_BIN must be set}"
: "${WAIT_UNIT:?WAIT_UNIT must be set}"
: "${WAIT_MAX_ATTEMPTS:=360}"
: "${WAIT_INTERVAL_SECONDS:=5}"

attempts=0
while "$SYSTEMCTL_BIN" is-active --quiet "$WAIT_UNIT"; do
  if ((attempts >= WAIT_MAX_ATTEMPTS)); then
    echo "Timed out waiting for $WAIT_UNIT to finish" >&2
    exit 1
  fi
  "$SLEEP_BIN" "$WAIT_INTERVAL_SECONDS"
  attempts=$((attempts + 1))
done
