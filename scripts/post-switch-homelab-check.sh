#!/usr/bin/env bash

set -euo pipefail

: "${HOMELAB_CHECK_BIN:=homelab-check}"
: "${SLEEP_BIN:=sleep}"
: "${READLINK_BIN:=readlink}"
: "${HOMELAB_CHECK_ATTEMPTS:=15}"
: "${HOMELAB_CHECK_RETRY_SECONDS:=10}"
: "${CURRENT_SYSTEM_LINK:=/run/current-system}"

if (( $# != 1 )); then
  echo "Usage: post-switch-homelab-check <previous-system-generation>" >&2
  exit 2
fi

if [[ ! $HOMELAB_CHECK_ATTEMPTS =~ ^[1-9][0-9]*$ ]] ||
  [[ ! $HOMELAB_CHECK_RETRY_SECONDS =~ ^[0-9]+$ ]]; then
  echo "Homelab check retry settings must be non-negative integers with at least one attempt" >&2
  exit 2
fi

previous_generation=$1

for ((attempt = 1; attempt <= HOMELAB_CHECK_ATTEMPTS; attempt++)); do
  printf 'Running post-switch homelab check (%s/%s)\n' "$attempt" "$HOMELAB_CHECK_ATTEMPTS"
  if "$HOMELAB_CHECK_BIN"; then
    echo "Post-switch homelab check passed"
    exit 0
  fi
  if ((attempt < HOMELAB_CHECK_ATTEMPTS)); then
    "$SLEEP_BIN" "$HOMELAB_CHECK_RETRY_SECONDS"
  fi
done

current_generation=$($READLINK_BIN -f "$CURRENT_SYSTEM_LINK" 2>/dev/null || printf unknown)
echo "Post-switch homelab check failed after $HOMELAB_CHECK_ATTEMPTS attempts" >&2
echo "Previous generation: $previous_generation" >&2
echo "Current generation:  $current_generation" >&2
echo "Review the failed checks before choosing whether to run: make rollback" >&2
exit 1
