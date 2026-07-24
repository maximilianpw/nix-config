#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/fleet-herdr.sh
source "$SCRIPT_DIR/lib/fleet-herdr.sh"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
HERDR_LOG="$TEST_DIR/herdr.log"

herdr() {
    printf '%s\n' "$*" >>"$HERDR_LOG"

    case "$1 $2" in
        "workspace create")
            printf '%s\n' '{"workspace_id":"workspace-1"}'
            ;;
        "pane list")
            if [[ "${FLEET_HERDR_TEST_NO_PANE:-0}" == 1 ]]; then
                printf '%s\n' '[]'
            else
                printf '%s\n' '[{"workspace_id":"workspace-1","pane_id":"pane-1"}]'
            fi
            ;;
        "pane run")
            printf '%s\n' '{"ok":true}'
            ;;
        "workspace close")
            printf '%s\n' '{"ok":true}'
            ;;
        *)
            return 90
            ;;
    esac
}

fleet_herdr_workspace kim kim
if ! grep -Fxq "pane run pane-1 exec fleet ssh kim" "$HERDR_LOG"; then
    echo "FAIL: Fleet command was not sent to the new Herdr pane" >&2
    exit 1
fi

: >"$HERDR_LOG"
export FLEET_HERDR_TEST_NO_PANE=1
if fleet_herdr_workspace kim kim 2>/dev/null; then
    echo "FAIL: missing Herdr pane unexpectedly succeeded" >&2
    exit 1
fi
if ! grep -Fxq "workspace close workspace-1" "$HERDR_LOG"; then
    echo "FAIL: incomplete Herdr workspace was not cleaned up" >&2
    exit 1
fi

if fleet_herdr_workspace 'kim;bad' kim 2>/dev/null; then
    echo "FAIL: unsafe Fleet host name was accepted" >&2
    exit 1
fi

echo "fleet Herdr tests passed"
