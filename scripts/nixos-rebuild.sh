#!/usr/bin/env bash
# NixOS/Darwin rebuild script with better error handling and validation, auto-detecting host and platform
set -euo pipefail

# Configuration
auto_username=$(whoami)
CONFIG_DIR="$HOME/nix-config"
LOG_FILE="$CONFIG_DIR/nixos-switch.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0

Automatically detects username and platform.

Host mapping:
  - max-vev: macbook-pro-m1 (darwin)
  - maxpw: main-pc (nixos)

On macOS, uses darwin-rebuild. On Linux, uses nixos-rebuild.
EOF
}

# Username to host mapping (map login -> flake config name)
declare -A USER_HOST_MAP
USER_HOST_MAP=(
  ["max-vev"]="macbook-pro-m1"
  ["maxpw"]="main-pc"
)

HOSTNAME="${USER_HOST_MAP[$auto_username]:-default}"

# Detect platform
UNAME_OUT="$(uname -s)"
if [[ "$UNAME_OUT" == "Darwin" ]]; then
    PLATFORM="darwin"
    REBUILD_CMD="darwin-rebuild"
    SYSTEM_HOSTNAME=$(scutil --get ComputerName 2>/dev/null || hostname)
    # Map current login or fallback to system name for Darwin
    HOSTNAME="${USER_HOST_MAP[$auto_username]:-$SYSTEM_HOSTNAME}"
    FLAKE_ATTR="darwinConfigurations.$HOSTNAME"
    FLAKE_SWITCH_ATTR="$HOSTNAME"
    info "Using Darwin flake config: $FLAKE_ATTR"
else
    PLATFORM="nixos"
    REBUILD_CMD="nixos-rebuild"
    # Map current login or fallback to hostname for NixOS
    HOSTNAME="${USER_HOST_MAP[$auto_username]:-$(hostname)}"
    FLAKE_ATTR="nixosConfigurations.$HOSTNAME"
    FLAKE_SWITCH_ATTR="$HOSTNAME"
fi

info "Detected user: $auto_username"
info "Selected host: $HOSTNAME"
info "Platform: $PLATFORM"
info "Rebuild command: $REBUILD_CMD"
info "Flake attribute: $FLAKE_ATTR"

# Change to config directory
if [[ ! -d "$CONFIG_DIR" ]]; then
    error "Config directory not found: $CONFIG_DIR"
    exit 1
fi

pushd "$CONFIG_DIR"

# Ensure /etc/nixos points to this repo (optional override: set SKIP_ETC_NIXOS_LINK=1)
if [[ "${SKIP_ETC_NIXOS_LINK:-0}" != "1" ]]; then
    TARGET_REAL=$(readlink -f /etc/nixos 2>/dev/null || echo "")
    if [[ -L /etc/nixos && "$TARGET_REAL" != "$CONFIG_DIR" ]]; then
        warn "/etc/nixos symlink points elsewhere ($TARGET_REAL). Updating to $CONFIG_DIR" && sudo ln -sfn "$CONFIG_DIR" /etc/nixos || warn "Failed to update symlink"
    elif [[ ! -e /etc/nixos ]]; then
        info "Creating /etc/nixos -> $CONFIG_DIR symlink" && sudo ln -sfn "$CONFIG_DIR" /etc/nixos || warn "Failed to create symlink"
    elif [[ -d /etc/nixos && ! -L /etc/nixos && "$TARGET_REAL" != "$CONFIG_DIR" ]]; then
        warn "/etc/nixos is a real directory (not symlink); leaving it untouched. Set SKIP_ETC_NIXOS_LINK=1 to silence."
    fi
fi

# Validate flake
info "Validating flake configuration..."
if ! nix flake check --no-build 2>/dev/null; then
    warn "Flake validation failed, continuing anyway..."
fi

# Format Nix files
info "Formatting Nix files..."
if command -v alejandra 2>&1; then
    alejandra . 2>&1 || warn "Formatting failed"
else
    warn "alejandra not found, skipping formatting"
fi

# Show changes
info "Showing changes in Nix files..."
if git diff --quiet HEAD -- '*.nix'; then
    info "No changes detected in Nix files"
else
    git diff --color=always -U2 '*.nix' || true
fi

# For Darwin, skip explicit nix build step; let darwin-rebuild handle everything
if [[ "$PLATFORM" == "nixos" ]]; then
    # The flake attribute (nixosConfigurations.<host>) is a set, not a derivation.
    # We must build its system build output.
    BUILD_ATTR="$FLAKE_ATTR.config.system.build.toplevel"
    info "Building NixOS system derivation: $BUILD_ATTR"
    if ! nix build ".#$BUILD_ATTR" --no-link 2>&1 | tee "$LOG_FILE"; then
        error "Build failed! Check the log above for details."
        exit 1
    fi
fi

# Apply the configuration
info "Applying configuration..."
if [[ "$PLATFORM" == "darwin" ]]; then
    if ! sudo darwin-rebuild switch --flake ".#$FLAKE_SWITCH_ATTR" 2>&1 | tee -a "$LOG_FILE"; then
        error "Rebuild failed! Check the log:"
        grep --color=always -E "(error|Error|ERROR|warning|Warning|WARN)" "$LOG_FILE" || true
        exit 1
    fi
else
    if ! sudo nixos-rebuild switch --flake ".#$FLAKE_SWITCH_ATTR" 2>&1 | tee -a "$LOG_FILE"; then
        error "Rebuild failed! Check the log:"
        grep --color=always -E "(error|Error|ERROR|warning|Warning|WARN)" "$LOG_FILE" || true
        exit 1
    fi
fi

success "Rebuild completed successfully!"

# Get current generation metadata
if [[ "$PLATFORM" == "darwin" ]]; then
    CURRENT_GEN=$(nix-env --list-generations --profile "$HOME/.nix-profile" | grep current | awk '{print $2 " " $3 " " $4}')
else
    CURRENT_GEN=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | grep current | awk '{print $2 " " $3 " " $4}')
fi
info "Current generation: $CURRENT_GEN"

# Commit changes if in a git repository
if git rev-parse --git-dir 2>&1; then
    if ! git diff --quiet HEAD -- '*.nix'; then
        info "Committing changes to git..."
        git add -A
        git commit -m "NixOS/Darwin rebuild: $HOSTNAME - Generation $CURRENT_GEN" || warn "Git commit failed"
    fi
fi

# Clean up old generations (keep last 10)
info "Cleaning up old generations..."
if [[ "$PLATFORM" == "darwin" ]]; then
    nix-collect-garbage --delete-older-than 30d 2>&1 || warn "Garbage collection failed"
else
    sudo nix-collect-garbage --delete-older-than 30d 2>&1 || warn "Garbage collection failed"
fi

success "All done! System is ready."
git add .
git commit -m "NixOS/Darwin configuration updated: $CURRENT_GEN" || echo "No changes to commit."
