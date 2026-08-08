#!/usr/bin/env bash
set -euo pipefail

if [[ -z ${FLEET_BIN:-} ]]; then
  printf '%s\n' 'fleet SSH regression skipped: FLEET_BIN is supplied by the Nix check.'
  exit 0
fi
: "${out:?out must be set by Nix runCommand}"

export SSH_ARGS_LOG="$TMPDIR/ssh-args"
export TMUX_ARGS_LOG="$TMPDIR/tmux-args"

"$FLEET_BIN" ssh kim
printf '%s\n' tm-kim >"$TMPDIR/expected-default"
diff -u "$TMPDIR/expected-default" "$SSH_ARGS_LOG"

"$FLEET_BIN" ssh kim agents
printf '%s\n' \
  -t \
  kim \
  "/run/current-system/sw/bin/tmux new-session -A -s 'agents'" >"$TMPDIR/expected-named"
diff -u "$TMPDIR/expected-named" "$SSH_ARGS_LOG"

"$FLEET_BIN" ssh kim agents --forward 3000 --forward 4000:5000
printf '%s\n' \
  -t \
  -o ExitOnForwardFailure=yes \
  -o ControlMaster=no \
  -o ControlPath=none \
  -L 127.0.0.1:3000:localhost:3000 \
  -L 127.0.0.1:4000:localhost:5000 \
  kim \
  "/run/current-system/sw/bin/tmux new-session -A -s 'agents'" >"$TMPDIR/expected-forwarded"
diff -u "$TMPDIR/expected-forwarded" "$SSH_ARGS_LOG"

"$FLEET_BIN" ssh kim --forward 5173
printf '%s\n' \
  -o ExitOnForwardFailure=yes \
  -o ControlMaster=no \
  -o ControlPath=none \
  -L 127.0.0.1:5173:localhost:5173 \
  tm-kim >"$TMPDIR/expected-forwarded-default"
diff -u "$TMPDIR/expected-forwarded-default" "$SSH_ARGS_LOG"

"$FLEET_BIN" ssh joyce local
printf '%s\n' new-session -A -s local >"$TMPDIR/expected-local"
diff -u "$TMPDIR/expected-local" "$TMUX_ARGS_LOG"

rm "$SSH_ARGS_LOG" "$TMUX_ARGS_LOG"
if "$FLEET_BIN" ssh kim invalid/session; then
  echo "fleet ssh accepted an unsafe session name" >&2
  exit 1
fi
test ! -e "$SSH_ARGS_LOG"
test ! -e "$TMUX_ARGS_LOG"

if "$FLEET_BIN" ssh kim --forward 3000:invalid; then
  echo "fleet ssh accepted an invalid forward" >&2
  exit 1
fi
test ! -e "$SSH_ARGS_LOG"
test ! -e "$TMUX_ARGS_LOG"

if "$FLEET_BIN" ssh joyce --forward 3000; then
  echo "fleet ssh accepted a local-host forward" >&2
  exit 1
fi
test ! -e "$SSH_ARGS_LOG"
test ! -e "$TMUX_ARGS_LOG"

touch "$out"
