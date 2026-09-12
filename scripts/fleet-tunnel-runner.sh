#!/usr/bin/env bash
set -euo pipefail

# Runs with Nix's Bash (wait -n/-p), not macOS's legacy /bin/bash. launchd owns
# this runner, which owns exactly one SSH child and one startup timer.
local_port="$1"
shift
ssh_pid=
timer_pid=

# Invoked indirectly by the EXIT trap (including the INT/TERM exit paths).
# shellcheck disable=SC2329
cleanup() {
  trap - EXIT INT TERM
  if [[ -n $timer_pid ]]; then
    kill "$timer_pid" 2>/dev/null || true
    wait "$timer_pid" 2>/dev/null || true
  fi
  if [[ -n $ssh_pid ]]; then
    # This is only our -N forwarding child, never a remote shell or an unrelated
    # listener. Force exit also covers an agent request stuck during startup.
    kill -KILL "$ssh_pid" 2>/dev/null || true
    wait "$ssh_pid" 2>/dev/null || true
  fi
}
trap 'cleanup' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

ssh "$@" </dev/null &
ssh_pid=$!
# The override is for disposable tests, not a plist setting.
sleep "${FLEET_TUNNEL_STARTUP_SECONDS:-45}" &
timer_pid=$!

status=0
wait -n -p finished "$ssh_pid" "$timer_pid" || status=$?
if [[ $finished == "$ssh_pid" ]]; then
  ssh_pid=
  exit "$status"
fi
timer_pid=

if ! timeout --kill-after=1s 3s lsof -nP -a -p "$ssh_pid" \
  -iTCP@127.0.0.1:"$local_port" -sTCP:LISTEN -t >/dev/null 2>&1; then
  exit 1
fi

# A healthy listener has no lifetime cap. Reconnects after it exits belong to
# launchd; the timer has already been reaped and leaves no background process.
status=0
wait "$ssh_pid" || status=$?
ssh_pid=
exit "$status"
