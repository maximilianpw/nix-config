#!/usr/bin/env bash
# Build the selected system without formatting, switching, or host mutation.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR=${1:-$PWD}

# shellcheck source=lib/host-detect.sh
source "$SCRIPT_DIR/lib/host-detect.sh"
detect_host
prepare_config_source "$CONFIG_DIR"
trap '[[ -z $CONFIG_SNAPSHOT_DIR ]] || rm -rf "$CONFIG_SNAPSHOT_DIR"' EXIT
FLAKE_REF=$(config_flake_ref "$CONFIG_SOURCE_DIR")
validate_host_configuration "$CONFIG_DIR" "$FLAKE_REF"

if [[ $PLATFORM == darwin ]]; then
    attr="darwinConfigurations.$HOSTNAME.system"
else
    attr="nixosConfigurations.$HOSTNAME.config.system.build.toplevel"
fi
# No exec: the EXIT trap must remove the snapshot. Preserve nix's status.
status=0
nix build "$FLAKE_REF#$attr" || status=$?
exit "$status"
