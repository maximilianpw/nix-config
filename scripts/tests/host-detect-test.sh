#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/host-detect.sh
source "$SCRIPT_DIR/lib/host-detect.sh"

failures=0

expect_host() {
    local expected_platform="$1"
    local expected_host="$2"
    local os="$3"
    local system_hostname="$4"
    local user="$5"
    local wsl="$6"

    unset NIX_CONFIG_HOST
    export NIX_CONFIG_TEST_WSL="$wsl"
    if ! detect_host "$os" "$system_hostname" "$user"; then
        echo "FAIL: detection unexpectedly failed for $os/$system_hostname/$user" >&2
        failures=$((failures + 1))
        return
    fi
    if [[ "$PLATFORM:$HOSTNAME" != "$expected_platform:$expected_host" ]]; then
        echo "FAIL: expected $expected_platform:$expected_host, got $PLATFORM:$HOSTNAME" >&2
        failures=$((failures + 1))
    fi
}

expect_host nixos kim Linux kim maxpw 0
expect_host nixos kim Linux main-pc maxpw 0
expect_host nixos build-box Linux build-box maxpw 0
expect_host nixos cuno Linux arbitrary maxpw 1
expect_host darwin joyce Darwin "Maxs-MacBook-Pro" max-vev 0

unset NIX_CONFIG_HOST
export NIX_CONFIG_TEST_WSL=0
if detect_host Darwin unknown stranger 2>/dev/null; then
    echo "FAIL: unknown Darwin login did not fail closed" >&2
    failures=$((failures + 1))
fi

export NIX_CONFIG_HOST=wsl
if ! detect_host Linux ignored maxpw || [[ "$HOSTNAME" != "cuno" ]]; then
    echo "FAIL: legacy explicit host override was not canonicalized" >&2
    failures=$((failures + 1))
fi

export NIX_CONFIG_HOST='../main-pc'
if detect_host Linux ignored maxpw 2>/dev/null; then
    echo "FAIL: unsafe explicit host override was accepted" >&2
    failures=$((failures + 1))
fi

# Validation and rebuilds must use an explicit path flake. A plain repository
# path is treated as a Git flake and silently excludes new, untracked modules.
PLATFORM="darwin"
HOSTNAME="joyce"
nix() {
    if [[ "${1:-}" == "eval" && "${2:-}" == "--raw" && "${3:-}" == 'path:/tmp/nix config#lib.hosts."joyce".os' ]]; then
        printf '%s\n' "darwin"
        return 0
    fi
    return 91
}
if ! validate_host_configuration "/tmp/nix config" 2>/dev/null; then
    echo "FAIL: inventory validation did not use an explicit path flake" >&2
    failures=$((failures + 1))
fi
unset -f nix

if ((failures > 0)); then
    exit 1
fi
echo "host detection tests passed"
