#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/rebuild-state.sh
source "$SCRIPT_DIR/lib/rebuild-state.sh"

tmpdir=$(mktemp -d)
trap '[[ -n "${test_pid:-}" ]] && kill "$test_pid" 2>/dev/null || true; rm -rf "$tmpdir"' EXIT
export NIX_CONFIG_STATE_DIR="$tmpdir/state"

bash -c 'while :; do sleep 30; done' nixos-rebuild.sh &
test_pid=$!
write_rebuild_state_for_pid "$test_pid"
validate_rebuild_state

chmod 644 "$REBUILD_STATE_FILE"
if validate_rebuild_state; then
    echo "FAIL: permissive state file mode was accepted" >&2
    exit 1
fi
chmod 600 "$REBUILD_STATE_FILE"

cleanup_rebuild_processes >/dev/null
wait "$test_pid" 2>/dev/null || true
if kill -0 "$test_pid" 2>/dev/null; then
    echo "FAIL: cleanup left the tracked root alive" >&2
    exit 1
fi
test_pid=""

echo "rebuild state tests passed"
