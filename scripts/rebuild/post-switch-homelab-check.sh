#!/usr/bin/env bash

set -euo pipefail

: "${HOMELAB_CHECK_BIN:=homelab-check}"
: "${SLEEP_BIN:=sleep}"
: "${READLINK_BIN:=readlink}"
# Allow the five-minute public-ingress scrape interval plus startup margin.
: "${HOMELAB_CHECK_ATTEMPTS:=36}"
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
attempt_output=$(mktemp)
trap 'rm -f "$attempt_output"' EXIT

# The rebuild pipes this script into its log, so it forwards whether the
# operator's terminal can show a redrawn status line.
live=0
if [[ -t 1 || ${HOMELAB_CHECK_LIVE:-0} == 1 ]]; then
  live=1
fi
show_status() {
  if ((live)); then
    printf '\r\033[2K\033[1m⏱ %ss\033[0m  %s' "$SECONDS" "$1"
  fi
}
clear_status() {
  if ((live)); then
    printf '\r\033[2K'
  fi
}

previous_failures=""
for ((attempt = 1; attempt <= HOMELAB_CHECK_ATTEMPTS; attempt++)); do
  show_status "Homelab check $attempt/$HOMELAB_CHECK_ATTEMPTS: running"
  if "$HOMELAB_CHECK_BIN" >"$attempt_output" 2>&1; then
    clear_status
    printf 'Post-switch homelab check passed (attempt %s/%s)\n' "$attempt" "$HOMELAB_CHECK_ATTEMPTS"
    exit 0
  fi
  failures=$(grep '^FAIL:' "$attempt_output" || tail -n 5 "$attempt_output")
  if ((attempt == 1)) || [[ $failures != "$previous_failures" ]]; then
    clear_status
    printf 'Homelab check %s/%s failed (retrying every %ss):\n' \
      "$attempt" "$HOMELAB_CHECK_ATTEMPTS" "$HOMELAB_CHECK_RETRY_SECONDS"
    sed 's/^/  /' <<< "$failures"
  elif ((!live)); then
    printf 'Homelab check %s/%s: still failing\n' "$attempt" "$HOMELAB_CHECK_ATTEMPTS"
  fi
  previous_failures=$failures
  if ((attempt < HOMELAB_CHECK_ATTEMPTS)); then
    if ((live)); then
      for ((left = HOMELAB_CHECK_RETRY_SECONDS; left > 0; left--)); do
        show_status "Homelab check $attempt/$HOMELAB_CHECK_ATTEMPTS failed; retrying in ${left}s"
        "$SLEEP_BIN" 1
      done
    else
      "$SLEEP_BIN" "$HOMELAB_CHECK_RETRY_SECONDS"
    fi
  fi
done
clear_status

current_generation=$($READLINK_BIN -f "$CURRENT_SYSTEM_LINK" 2>/dev/null || printf unknown)
echo "Full output of the last homelab check:" >&2
cat "$attempt_output" >&2
echo "Post-switch homelab check failed after $HOMELAB_CHECK_ATTEMPTS attempts" >&2
echo "Previous generation: $previous_generation" >&2
echo "Current generation:  $current_generation" >&2
echo "Review the failed checks before choosing whether to run: make rollback" >&2
exit 1
