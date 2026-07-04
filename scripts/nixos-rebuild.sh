#!/usr/bin/env bash
# NixOS/Darwin rebuild script, auto-detecting host and platform.
# Build, switch, and generation cleanup are delegated to nh (nix helper),
# which prints a package-level generation diff after every switch and keeps
# a rollback floor when cleaning. This script keeps the repo-specific parts:
# user->host mapping, /etc/nixos symlink upkeep, formatting, and the log.
set -euo pipefail

# Configuration
auto_username=$(whoami)
CONFIG_DIR="$HOME/nix-config"
LOG_FILE="$CONFIG_DIR/nixos-switch.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

# nh is installed by this very config, so the first rebuild on a fresh
# machine won't have it on PATH yet - fall back to running it from nixpkgs.
if command -v nh >/dev/null 2>&1; then
    NH=(nh)
else
    warn "nh not on PATH yet (first rebuild?); using 'nix run nixpkgs#nh'"
    NH=(nix run nixpkgs#nh --)
fi

# Platform + host detection (login -> flake config mapping) is shared with
# bootstrap.sh; the map lives in scripts/lib/host-detect.sh.
# shellcheck source=lib/host-detect.sh
source "$SCRIPT_DIR/lib/host-detect.sh"
detect_host

if [[ "$PLATFORM" == "darwin" ]]; then
    # Determinate Nix writes `lazy-trees = true` into /etc/nix/nix.conf.
    # nix-output-monitor links against upstream libnix, which does not know
    # that Determinate-specific setting and warns during Darwin builds.
    NH_SWITCH=("${NH[@]}" darwin switch --no-nom)
else
    NH_SWITCH=("${NH[@]}" os switch)
    if [[ "$HOSTNAME" == "wsl" ]]; then
        info "WSL environment detected, using wsl config"
    fi
fi

info "Detected user: $auto_username"
info "Selected host: $HOSTNAME"
info "Platform: $PLATFORM"

# Lockout guard: on full NixOS the user password comes from a sops secret
# (users/maxpw/nixos.nix, neededForUsers), so switching without the age key
# leaves the user with no password. Checked without sudo to keep daily
# rebuilds prompt-free: the key's parent dir only exists once the key has
# been placed (see secrets/README.md), so a missing dir means a missing key.
if [[ "$PLATFORM" == "nixos" && "$HOSTNAME" != "wsl" && "${SKIP_SOPS_CHECK:-0}" != "1" ]]; then
    if [[ ! -e /var/lib/sops-nix/key.txt && ! -d /var/lib/sops-nix ]]; then
        error "No sops age key at /var/lib/sops-nix/key.txt - rebuilding now would"
        error "leave user '$auto_username' with NO password (lockout)."
        echo ""
        echo "Retrieve the key from 1Password (item: 'sops nixos') and place it there;"
        echo "see secrets/README.md ('Setting up a New NixOS Machine') for the commands."
        echo "Set SKIP_SOPS_CHECK=1 to bypass this check - NOT recommended."
        exit 1
    fi
fi

# Change to config directory
if [[ ! -d "$CONFIG_DIR" ]]; then
    error "Config directory not found: $CONFIG_DIR"
    exit 1
fi

pushd "$CONFIG_DIR" >/dev/null

# Keep failure summaries scoped to the current rebuild attempt.
: > "$LOG_FILE"

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

# Format Nix files
info "Formatting Nix files..."
if command -v alejandra >/dev/null 2>&1; then
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

# Build + switch via nh (elevates itself, prints an nvd generation diff).
# Output is teed to the log; nh degrades to sequential lines when piped.
info "Switching configuration via nh: $HOSTNAME ($PLATFORM)"
if ! "${NH_SWITCH[@]}" -H "$HOSTNAME" "$CONFIG_DIR" 2>&1 | tee -a "$LOG_FILE"; then
    error "Rebuild failed! Check the log:"
    grep --color=always -E "(error|Error|ERROR|warning|Warning|WARN)" "$LOG_FILE" || true
    exit 1
fi

success "Rebuild completed successfully!"

# Clean up old generations: always keep the last 5 as a rollback floor,
# plus anything newer than 30 days (the old age-only GC could delete
# every rollback target after an idle month).
info "Cleaning up old generations (keep 5, keep 30d)..."
if ! "${NH[@]}" clean all --keep 5 --keep-since 30d 2>&1 | tee -a "$LOG_FILE"; then
    warn "Generation cleanup failed"
fi

success "All done! System is ready."
