#!/usr/bin/env bash
# NixOS rebuild script with better error handling and validation
set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/Nix-Config"
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
Usage: $0 <hostname>

Available hosts:
  - default: Standard VM configuration
  - bigboy:  High-performance VM with NVIDIA
  - mac:     ARM64 VM for Mac (VMware Fusion)

Examples:
  $0 default
  $0 bigboy
  $0 mac
EOF
}

# Check arguments
if [[ $# -ne 1 ]]; then
    error "Missing hostname argument"
    usage
    exit 1
fi

HOSTNAME="$1"
VALID_HOSTS=("default" "bigboy" "mac")

if [[ ! " ${VALID_HOSTS[*]} " =~ " ${HOSTNAME} " ]]; then
    error "Invalid hostname: $HOSTNAME"
    usage
    exit 1
fi

# Change to config directory
if [[ ! -d "$CONFIG_DIR" ]]; then
    error "Config directory not found: $CONFIG_DIR"
    exit 1
fi

pushd "$CONFIG_DIR"

# Validate flake
info "Validating flake configuration..."
if ! nix flake check --no-build 2>/dev/null; then
    warn "Flake validation failed, continuing anyway..."
fi

# Format Nix files
info "Formatting Nix files..."
if command -v alejandra >/dev/null 2>&1; then
    alejandra . >/dev/null 2>&1 || warn "Formatting failed"
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

# Build the configuration first
info "Building NixOS configuration for host: $HOSTNAME"
if ! nix build ".#nixosConfigurations.$HOSTNAME.config.system.build.toplevel" --no-link 2>&1 | tee "$LOG_FILE"; then
    error "Build failed! Check the log above for details."
    exit 1
fi

# Apply the configuration
info "Applying NixOS configuration..."
if ! sudo nixos-rebuild switch --flake "./#$HOSTNAME" 2>&1 | tee -a "$LOG_FILE"; then
    error "Rebuild failed! Check the log:"
    grep --color=always -E "(error|Error|ERROR|warning|Warning|WARN)" "$LOG_FILE" || true
    exit 1
fi

success "Rebuild completed successfully!"

# Get current generation metadata
CURRENT_GEN=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | grep current | awk '{print $2 " " $3 " " $4}')
info "Current generation: $CURRENT_GEN"

# Commit changes if in a git repository
if git rev-parse --git-dir >/dev/null 2>&1; then
    if ! git diff --quiet HEAD -- '*.nix'; then
        info "Committing changes to git..."
        git add -A
        git commit -m "NixOS rebuild: $HOSTNAME - Generation $CURRENT_GEN" || warn "Git commit failed"
    fi
fi

# Clean up old generations (keep last 10)
info "Cleaning up old generations..."
sudo nix-collect-garbage --delete-older-than 30d >/dev/null 2>&1 || warn "Garbage collection failed"

success "All done! System is ready."
git add .
git commit -m "NixOS configuration updated: $CURRENT_GEN" || echo "No changes to commit."

# Back to where you were
popd >/dev/null
