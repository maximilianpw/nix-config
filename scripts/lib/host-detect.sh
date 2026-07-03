# shellcheck shell=bash
# shellcheck disable=SC2034  # PLATFORM/HOSTNAME are consumed by the sourcing script
# Shared host/platform detection for bootstrap.sh and nixos-rebuild.sh.
# Source this file, then call detect_host. Sets:
#   PLATFORM  - "darwin" or "nixos"
#   HOSTNAME  - flake configuration name to build
#
# Uses a case statement (not an associative array) so it also works on the
# stock macOS /bin/bash 3.2 during a fresh bootstrap, before Nix provides a
# newer bash.

# Login name -> flake config name. Add a line here when adding a machine to
# flake.nix (this is the only place the mapping lives).
map_user_to_host() {
    case "$1" in
        max-vev) echo "macbook-pro-m1" ;;
        maxpw) echo "main-pc" ;;
        *) echo "" ;;
    esac
}

detect_host() {
    local user mapped
    user=$(whoami)
    mapped=$(map_user_to_host "$user")

    if [[ "$(uname -s)" == "Darwin" ]]; then
        PLATFORM="darwin"
        local sysname
        sysname=$(scutil --get ComputerName 2>/dev/null || hostname)
        HOSTNAME="${mapped:-$sysname}"
    else
        PLATFORM="nixos"
        HOSTNAME="${mapped:-$(hostname)}"
        # WSL detection: override hostname when running under WSL
        if [[ -e /proc/sys/fs/binfmt_misc/WSLInterp ]] || grep -qi microsoft /proc/version 2>/dev/null; then
            HOSTNAME="wsl"
        fi
    fi
}
