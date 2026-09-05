#!/usr/bin/env bash
# Build the selected system without formatting, switching, or host mutation.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR=${1:-$PWD}

# shellcheck source=lib/host-detect.sh
source "$SCRIPT_DIR/lib/host-detect.sh"
detect_host
validate_host_configuration "$CONFIG_DIR"
FLAKE_REF=$(config_flake_ref "$CONFIG_DIR")

if [[ $PLATFORM == darwin ]]; then
    exec nix build "$FLAKE_REF#darwinConfigurations.$HOSTNAME.system"
else
    exec nix build "$FLAKE_REF#nixosConfigurations.$HOSTNAME.config.system.build.toplevel"
fi
