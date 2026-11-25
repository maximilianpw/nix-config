#!/usr/bin/env bash

set -euo pipefail

: "${PKILL_BIN:?PKILL_BIN must be set}"
: "${TAIL_BIN:?TAIL_BIN must be set}"

# systemd leaves MAINPID unset when the application has already exited.
if (( $# == 0 )); then
  exit 0
fi
if (( $# != 1 )); then
  echo "Plex stop: expected only the bubblewrap main PID" >&2
  exit 2
fi
main_pid=$1
if [[ -z $main_pid ]]; then
  exit 0
fi
if [[ ! $main_pid =~ ^[1-9][0-9]*$ || $main_pid == 1 ]]; then
  echo "Plex stop: invalid bubblewrap main PID" >&2
  exit 2
fi

# Plex is the FHS wrapper's direct child. Signalling bwrap first triggers its
# --die-with-parent SIGKILL before Plex can flush state and stop its helpers.
if "$PKILL_BIN" --signal TERM --parent "$main_pid"; then
  :
else
  status=$?
  if (( status != 1 )); then
    exit "$status"
  fi
  echo "Plex stop: no application child signalled; waiting for wrapper exit" >&2
fi

# ExecStop must wait: returning early lets systemd kill the wrapper too soon.
# The unit's TimeoutStopSec still bounds a stuck application shutdown.
exec "$TAIL_BIN" --pid="$main_pid" --sleep-interval=0.1 --follow /dev/null
