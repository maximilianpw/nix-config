#!/usr/bin/env bash
# Bootstrap script for setting up nix-config on a new system
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Helper functions
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
step() { echo -e "${CYAN}[STEP]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Bootstrap a new system with nix-config.

OPTIONS:
    -h, --help          Show this help message
    -s, --skip-clone    Skip cloning the repository (use if already cloned)
    -d, --dry-run       Show what would be done without executing

This script will:
  1. Check for Nix installation (and offer to install if missing)
  2. Clone the nix-config repository to ~/nix-config (if not present)
  3. Set up /etc/nixos symlink (NixOS only)
  4. Enable flakes and nix-command
  5. Update flake inputs
  6. Perform initial system rebuild

EOF
}

# Parse arguments
SKIP_CLONE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -s|--skip-clone)
            SKIP_CLONE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Detect platform
UNAME_OUT="$(uname -s)"
if [[ "$UNAME_OUT" == "Darwin" ]]; then
    PLATFORM="darwin"
else
    PLATFORM="nixos"
fi

info "Detected platform: $PLATFORM"

# Check if running in dry-run mode
if [[ "$DRY_RUN" == "true" ]]; then
    warn "Running in DRY-RUN mode - no changes will be made"
fi

# Step 1: Check for Nix installation
step "1/6: Checking Nix installation..."
if ! command -v nix &> /dev/null; then
    error "Nix is not installed!"
    echo ""
    echo "Please install Nix first:"
    if [[ "$PLATFORM" == "darwin" ]]; then
        echo "  Recommended: Determinate Nix Installer"
        echo "  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    else
        echo "  For NixOS: Nix should be pre-installed"
        echo "  For other Linux: https://nixos.org/download.html"
    fi
    exit 1
else
    NIX_VERSION=$(nix --version)
    success "Nix is installed: $NIX_VERSION"
fi

# Step 2: Enable flakes if not already enabled
step "2/6: Ensuring flakes are enabled..."
NIX_CONF_DIR="$HOME/.config/nix"
NIX_CONF="$NIX_CONF_DIR/nix.conf"

if [[ ! -f "$NIX_CONF" ]]; then
    info "Creating nix.conf with experimental features..."
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$NIX_CONF_DIR"
        cat > "$NIX_CONF" << 'NIXCONF'
experimental-features = nix-command flakes
NIXCONF
        success "Created $NIX_CONF"
    else
        info "[DRY-RUN] Would create $NIX_CONF"
    fi
else
    if ! grep -q "experimental-features.*flakes" "$NIX_CONF"; then
        warn "Adding flakes to existing nix.conf..."
        if [[ "$DRY_RUN" == "false" ]]; then
            echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
            success "Updated $NIX_CONF"
        else
            info "[DRY-RUN] Would add flakes to $NIX_CONF"
        fi
    else
        success "Flakes already enabled in $NIX_CONF"
    fi
fi

# Step 3: Clone or verify repository
step "3/6: Setting up nix-config repository..."
CONFIG_DIR="$HOME/nix-config"

if [[ "$SKIP_CLONE" == "true" ]]; then
    info "Skipping repository clone as requested"
    if [[ ! -d "$CONFIG_DIR" ]]; then
        error "Config directory not found: $CONFIG_DIR"
        error "Remove --skip-clone flag to clone the repository"
        exit 1
    fi
elif [[ -d "$CONFIG_DIR" ]]; then
    warn "Directory $CONFIG_DIR already exists"
    if [[ -d "$CONFIG_DIR/.git" ]]; then
        success "Git repository found at $CONFIG_DIR"
        pushd "$CONFIG_DIR" > /dev/null
        CURRENT_BRANCH=$(git branch --show-current)
        info "Current branch: $CURRENT_BRANCH"
        popd > /dev/null
    else
        error "$CONFIG_DIR exists but is not a git repository"
        exit 1
    fi
else
    info "Cloning nix-config repository..."
    if [[ "$DRY_RUN" == "false" ]]; then
        # Note: Update this URL to your actual repository
        warn "Update the repository URL in this script!"
        echo "Example: git clone https://github.com/yourusername/nix-config.git $CONFIG_DIR"
        error "Please edit scripts/bootstrap.sh and update the git clone URL"
        exit 1
    else
        info "[DRY-RUN] Would clone repository to $CONFIG_DIR"
    fi
fi

# Step 4: Set up /etc/nixos symlink (NixOS only)
if [[ "$PLATFORM" == "nixos" ]]; then
    step "4/6: Setting up /etc/nixos symlink..."
    TARGET_REAL=$(readlink -f /etc/nixos 2>/dev/null || echo "")

    if [[ -L /etc/nixos && "$TARGET_REAL" == "$CONFIG_DIR" ]]; then
        success "/etc/nixos already points to $CONFIG_DIR"
    elif [[ ! -e /etc/nixos ]]; then
        info "Creating /etc/nixos -> $CONFIG_DIR symlink"
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo ln -sfn "$CONFIG_DIR" /etc/nixos
            success "Created symlink"
        else
            info "[DRY-RUN] Would create symlink /etc/nixos -> $CONFIG_DIR"
        fi
    elif [[ -L /etc/nixos ]]; then
        warn "/etc/nixos points to $TARGET_REAL, updating to $CONFIG_DIR"
        if [[ "$DRY_RUN" == "false" ]]; then
            sudo ln -sfn "$CONFIG_DIR" /etc/nixos
            success "Updated symlink"
        else
            info "[DRY-RUN] Would update symlink /etc/nixos -> $CONFIG_DIR"
        fi
    elif [[ -d /etc/nixos ]]; then
        warn "/etc/nixos is a directory, not a symlink"
        echo "You may want to back it up and replace it with a symlink:"
        echo "  sudo mv /etc/nixos /etc/nixos.backup"
        echo "  sudo ln -sfn $CONFIG_DIR /etc/nixos"
    fi
else
    step "4/6: Skipping /etc/nixos symlink (not on NixOS)"
fi

# Step 5: Update flake inputs
step "5/6: Updating flake inputs..."
pushd "$CONFIG_DIR" > /dev/null
if [[ "$DRY_RUN" == "false" ]]; then
    if nix flake update; then
        success "Flake inputs updated"
    else
        warn "Flake update failed, continuing anyway..."
    fi
else
    info "[DRY-RUN] Would run: nix flake update"
fi
popd > /dev/null

# Step 6: Perform initial rebuild
step "6/6: Ready for initial system rebuild"
echo ""
info "Bootstrap preparation complete!"
echo ""
echo "Next steps:"
echo "  1. Review the configuration in $CONFIG_DIR"
echo "  2. Customize for your system (hostname, user, etc.)"
echo "  3. Run the rebuild script:"
if [[ "$PLATFORM" == "darwin" ]]; then
    echo "     ./scripts/nixos-rebuild.sh"
    echo "     OR"
    echo "     sudo darwin-rebuild switch --flake $CONFIG_DIR#macbook-pro-m1"
else
    echo "     ./scripts/nixos-rebuild.sh"
    echo "     OR"
    echo "     sudo nixos-rebuild switch --flake $CONFIG_DIR#main-pc"
fi
echo ""

if [[ "$DRY_RUN" == "false" ]]; then
    read -p "Do you want to run the initial rebuild now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Starting initial rebuild..."
        exec "$CONFIG_DIR/scripts/nixos-rebuild.sh"
    else
        info "Skipping initial rebuild. Run it manually when ready."
    fi
else
    info "[DRY-RUN] Would prompt for initial rebuild"
fi

success "Bootstrap complete! 🚀"
