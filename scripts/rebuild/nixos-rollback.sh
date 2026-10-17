#!/usr/bin/env bash
# Roll the system back one generation, then run the same runtime checks as a
# rebuild so a rollback on Kim is verified rather than assumed healthy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${CURRENT_SYSTEM_LINK:=/run/current-system}"

# shellcheck source=lib/host-detect.sh
source "$SCRIPT_DIR/lib/host-detect.sh"
detect_host

previous_system_generation=$(readlink -f "$CURRENT_SYSTEM_LINK" 2>/dev/null || printf unknown)
echo "Rolling $HOSTNAME ($PLATFORM) back from $previous_system_generation..."
if [[ "$PLATFORM" == "darwin" ]]; then
    # darwin-rebuild treats --rollback as its own action.
    sudo darwin-rebuild --rollback
else
    # Without an action nixos-rebuild prints its manual and exits 0.
    sudo nixos-rebuild switch --rollback
fi
echo "Now on $(readlink -f "$CURRENT_SYSTEM_LINK" 2>/dev/null || printf unknown)"

if [[ "$PLATFORM" == "nixos" && "$HOSTNAME" == "kim" ]]; then
    echo "Running post-rollback homelab verification..."
    HOMELAB_CHECK_BIN="${HOMELAB_CHECK_BIN:-$CURRENT_SYSTEM_LINK/sw/bin/homelab-check}" \
        "$SCRIPT_DIR/post-switch-homelab-check.sh" "$previous_system_generation"
fi
echo "Rollback complete!"
