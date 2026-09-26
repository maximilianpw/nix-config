# shellcheck shell=bash
# shellcheck disable=SC2034  # PLATFORM/HOSTNAME/CONFIG_* are consumed by the sourcing script
# Shared fail-closed host/platform detection and flake source preparation for
# bootstrap.sh, nixos-build.sh, and nixos-rebuild.sh. Linux uses the real
# hostname; login-name mapping is only a Darwin fallback where the macOS
# ComputerName is not the flake host name.

map_darwin_user_to_host() {
    case "$1" in
        max-vev) printf '%s\n' "joyce" ;;
        *) return 1 ;;
    esac
}

canonical_host_name() {
    case "$1" in
        main-pc) printf '%s\n' "kim" ;;
        macbook-pro-m1) printf '%s\n' "joyce" ;;
        wsl) printf '%s\n' "cuno" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

valid_host_name() {
    case "$1" in
        ""|*[!A-Za-z0-9_-]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Use the path flake fetcher deliberately. A plain path inside a Git worktree
# becomes a Git flake, which excludes untracked modules and can make a valid
# in-progress configuration look as though its host does not exist.
config_flake_ref() {
    printf 'path:%s\n' "$1"
}

# The path fetcher also ignores .gitignore, so evaluating the worktree directly
# copies scratch artifacts, logs, direnv state, and any stray plaintext secret
# into the world-readable store. Inside a Git worktree, snapshot what Git would
# offer to commit instead: tracked files that still exist plus untracked,
# non-ignored files. Sets CONFIG_SOURCE_DIR (the directory to evaluate) and
# CONFIG_SNAPSHOT_DIR (a temporary directory the caller must remove, or empty).
prepare_config_source() {
    local config_dir="$1"
    local toplevel file
    CONFIG_SOURCE_DIR="$config_dir"
    CONFIG_SNAPSHOT_DIR=""

    if ! toplevel=$(git -C "$config_dir" rev-parse --show-toplevel 2>/dev/null) ||
        [[ -z "$toplevel" ]] ||
        [[ "$(cd "$toplevel" && pwd -P)" != "$(cd "$config_dir" && pwd -P)" ]]; then
        return 0
    fi

    CONFIG_SNAPSHOT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/nix-config-source.XXXXXX")
    # Nix's path flake fetcher rejects symlinked ancestors (macOS /var and
    # /tmp included), so use the physical path for both evaluation and cleanup.
    CONFIG_SNAPSHOT_DIR=$(cd "$CONFIG_SNAPSHOT_DIR" && pwd -P)
    git -C "$config_dir" ls-files -z --cached --others --exclude-standard |
        while IFS= read -r -d '' file; do
            # Deleted-but-tracked paths are still listed by --cached.
            [[ -e "$config_dir/$file" || -L "$config_dir/$file" ]] && printf '%s\0' "$file"
        done |
        tar -C "$config_dir" --null -T - -cf - |
        tar -C "$CONFIG_SNAPSHOT_DIR" -xf -
    CONFIG_SOURCE_DIR="$CONFIG_SNAPSHOT_DIR"
}

detect_wsl() {
    if [[ -n "${NIX_CONFIG_TEST_WSL:-}" ]]; then
        [[ "$NIX_CONFIG_TEST_WSL" == "1" ]]
        return
    fi

    [[ -e /proc/sys/fs/binfmt_misc/WSLInterp ]] ||
        grep -qi microsoft /proc/version 2>/dev/null
}

# Optional arguments make the function deterministic in regression tests:
# detect_host [uname] [hostname] [user]
detect_host() {
    local os detected_hostname user mapped
    os="${1:-$(uname -s)}"
    detected_hostname="${2:-$(hostname -s 2>/dev/null || hostname)}"
    user="${3:-$(whoami)}"

    if [[ -n "${NIX_CONFIG_HOST:-}" ]]; then
        if ! valid_host_name "$NIX_CONFIG_HOST"; then
            echo "Invalid NIX_CONFIG_HOST: '$NIX_CONFIG_HOST'" >&2
            return 1
        fi
        HOSTNAME=$(canonical_host_name "$NIX_CONFIG_HOST")
        if [[ "$os" == "Darwin" ]]; then
            PLATFORM="darwin"
        else
            PLATFORM="nixos"
        fi
        return 0
    fi

    if [[ "$os" == "Darwin" ]]; then
        PLATFORM="darwin"
        if ! mapped=$(map_darwin_user_to_host "$user"); then
            echo "No Darwin flake host mapping for login '$user'." >&2
            echo "Set NIX_CONFIG_HOST explicitly or add the host to lib/hosts.nix." >&2
            return 1
        fi
        HOSTNAME="$mapped"
        return 0
    fi

    PLATFORM="nixos"
    if detect_wsl; then
        HOSTNAME="cuno"
        return 0
    fi

    # Strip a DNS suffix but do not map all Linux logins to kim. A new or
    # misnamed Linux host must fail later inventory validation instead of
    # accidentally switching kim's configuration.
    detected_hostname="${detected_hostname%%.*}"
    if ! valid_host_name "$detected_hostname"; then
        echo "Could not derive a safe flake host name from '$detected_hostname'." >&2
        echo "Set NIX_CONFIG_HOST explicitly after checking lib/hosts.nix." >&2
        return 1
    fi
    HOSTNAME=$(canonical_host_name "$detected_hostname")
}

# validate_host_configuration <config-dir> [flake-ref]
# Pass the flake ref from prepare_config_source to avoid re-copying the tree.
validate_host_configuration() {
    local config_dir="$1"
    local flake_ref="${2:-$(config_flake_ref "$config_dir")}"
    local expected_kind actual_kind

    if [[ "$PLATFORM" == "darwin" ]]; then
        expected_kind="darwin"
    else
        expected_kind="nixos"
    fi

    if ! actual_kind=$(nix eval --raw "$flake_ref#lib.hosts.\"$HOSTNAME\".os"); then
        echo "Unable to evaluate host '$HOSTNAME' from $config_dir/lib/hosts.nix." >&2
        echo "The Nix error above is the underlying configuration failure." >&2
        return 1
    fi

    case "$expected_kind:$actual_kind" in
        darwin:darwin|nixos:nixos|nixos:nixos-wsl) return 0 ;;
        *)
            echo "Host '$HOSTNAME' is '$actual_kind', not '$expected_kind'." >&2
            return 1
            ;;
    esac
}
