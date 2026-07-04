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
    -u, --update        Update flake inputs before the initial rebuild
                        (default: build from the committed, CI-tested flake.lock)

ENVIRONMENT:
    NIX_CONFIG_REPO_URL Override the clone URL (default: HTTPS GitHub URL;
                        SSH only works once the 1Password agent is set up)
    SKIP_SOPS_CHECK=1   Skip the sops age key check (not recommended; on NixOS
                        the first rebuild will lock you out of your user if
                        the system key is genuinely missing)

This script will:
  1. Check for Nix installation (and point at the installer if missing)
  2. Check platform prerequisites (macOS: Xcode CLT + Homebrew)
  3. Enable flakes and nix-command
  4. Clone the nix-config repository to ~/nix-config (if not present)
  5. Set up /etc/nixos symlink (NixOS only)
  6. Verify this host has a configuration in flake.nix
  7. Verify the sops age key is in place
  8. Optionally update flake inputs (--update), then offer the initial rebuild

For the full new-machine runbook (ISO to running system, secrets, new-host
setup), see BOOTSTRAP.md.

EOF
}

# Parse arguments
SKIP_CLONE=false
DRY_RUN=false
UPDATE_INPUTS=false

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
        -u|--update)
            UPDATE_INPUTS=true
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

# HTTPS by default: a fresh machine has no SSH keys yet (they come from the
# 1Password agent, which this config sets up). Switch the remote to SSH later:
#   git remote set-url origin git@github.com:maximilianpw/nix-config.git
REPO_URL="${NIX_CONFIG_REPO_URL:-https://github.com/maximilianpw/nix-config.git}"

info "Detected platform: $PLATFORM"

# Check if running in dry-run mode
if [[ "$DRY_RUN" == "true" ]]; then
    warn "Running in DRY-RUN mode - no changes will be made"
fi

# Step 1: Check for Nix installation
step "1/8: Checking Nix installation..."
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

# Step 2: Platform prerequisites
if [[ "$PLATFORM" == "darwin" ]]; then
    step "2/8: Checking macOS prerequisites (Xcode CLT, Homebrew)..."
    PREREQS_OK=true

    # git (and clang etc.) on macOS come from the Xcode Command Line Tools;
    # without them the /usr/bin/git shim just errors out.
    if ! xcode-select -p &> /dev/null; then
        PREREQS_OK=false
        error "Xcode Command Line Tools are not installed"
        echo "  Install with:  xcode-select --install"
    else
        success "Xcode Command Line Tools found: $(xcode-select -p)"
    fi

    # nix-darwin's homebrew module manages casks/brews but does NOT install
    # Homebrew itself - the first darwin-rebuild fails without it.
    if command -v brew &> /dev/null || [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]]; then
        success "Homebrew found"
    else
        PREREQS_OK=false
        error "Homebrew is not installed (required: darwin config manages casks via Homebrew)"
        echo "  Install with:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    fi

    if [[ "$PREREQS_OK" == "false" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            warn "[DRY-RUN] Missing prerequisites above would abort the bootstrap"
        else
            error "Install the missing prerequisites above, then re-run this script"
            exit 1
        fi
    fi
else
    step "2/8: No extra prerequisites on NixOS"
fi

# Step 3: Enable flakes if not already enabled
step "3/8: Ensuring flakes are enabled..."
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

# Step 4: Clone or verify repository
step "4/8: Setting up nix-config repository..."
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
    info "Cloning nix-config repository from $REPO_URL..."
    if [[ "$DRY_RUN" == "false" ]]; then
        git clone "$REPO_URL" "$CONFIG_DIR"
        success "Repository cloned to $CONFIG_DIR"
    else
        info "[DRY-RUN] Would run: git clone $REPO_URL $CONFIG_DIR"
    fi
fi

# Step 5: Set up /etc/nixos symlink (NixOS only)
if [[ "$PLATFORM" == "nixos" ]]; then
    step "5/8: Setting up /etc/nixos symlink..."
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
    step "5/8: Skipping /etc/nixos symlink (not on NixOS)"
fi

# Step 6: Verify this host has a configuration in the flake
step "6/8: Verifying this host has a flake configuration..."
# shellcheck source=lib/host-detect.sh
source "$CONFIG_DIR/scripts/lib/host-detect.sh"
detect_host
info "Detected host: $HOSTNAME ($PLATFORM)"

if [[ "$PLATFORM" == "darwin" ]]; then
    FLAKE_ATTR="darwinConfigurations"
else
    FLAKE_ATTR="nixosConfigurations"
fi

# Cheap textual check (avoids evaluating the flake, which would download all
# inputs just to list attribute names). flake.nix declares hosts literally as
# `nixosConfigurations.<name> = mkSystem ...`.
if grep -qE "${FLAKE_ATTR}\.\"?${HOSTNAME}\"? *=" "$CONFIG_DIR/flake.nix"; then
    success "Found ${FLAKE_ATTR}.${HOSTNAME} in flake.nix"
else
    error "No ${FLAKE_ATTR}.${HOSTNAME} in flake.nix - the rebuild would fail"
    echo ""
    echo "This looks like a new machine. To add it (see BOOTSTRAP.md, 'Adding a new host'):"
    echo "  1. Create machines/${HOSTNAME}.nix (and hardware config under machines/hardware/)"
    echo "  2. Add a mkSystem entry for '${HOSTNAME}' in flake.nix"
    echo "  3. Map your login to the host in scripts/lib/host-detect.sh"
    echo "  4. Commit, then re-run this script with --skip-clone"
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "[DRY-RUN] This would abort the bootstrap"
    else
        exit 1
    fi
fi

# Step 7: Verify the sops age key is in place.
# users/maxpw/nixos.nix sets the user password from a sops secret with
# neededForUsers = true. If the age key is missing on the first rebuild,
# the user ends up with no password - i.e. locked out of the new system.
# Darwin Home Manager also decrypts user secrets, including the dedicated
# fleet SSH key used for unattended Mac -> main-pc connections.
if [[ "${SKIP_SOPS_CHECK:-0}" == "1" ]]; then
    step "7/8: Skipping sops age key check (SKIP_SOPS_CHECK=1)"
elif [[ "$PLATFORM" == "darwin" ]]; then
    step "7/8: Checking user sops age key (needed for Home Manager secrets)..."
    USER_SOPS_KEY="$HOME/.config/sops/age/keys.txt"
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would check $USER_SOPS_KEY exists"
    elif [[ -f "$USER_SOPS_KEY" ]]; then
        success "Age key found at $USER_SOPS_KEY"
    else
        error "No age key at $USER_SOPS_KEY"
        echo ""
        echo "Darwin Home Manager uses sops secrets for local app secrets and"
        echo "the dedicated fleet SSH key for Mac -> main-pc. Retrieve the age"
        echo "key from 1Password (vault: Personal, item: 'sops nixos'):"
        echo ""
        echo "  mkdir -p ~/.config/sops/age"
        echo "  nix-shell -p _1password-cli --run 'eval \$(op signin); op item get \"sops nixos\" --fields password --reveal' >> ~/.config/sops/age/keys.txt"
        echo "  chmod 600 ~/.config/sops/age/keys.txt"
        echo ""
        echo "Then re-run this script with --skip-clone."
        echo "(Set SKIP_SOPS_CHECK=1 to bypass this check - NOT recommended.)"
        exit 1
    fi
elif [[ "$PLATFORM" == "nixos" && "$HOSTNAME" != "wsl" ]]; then
    step "7/8: Checking sops age key (prevents user lockout)..."
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would check /var/lib/sops-nix/key.txt exists (needs sudo)"
    elif sudo test -f /var/lib/sops-nix/key.txt; then
        success "Age key found at /var/lib/sops-nix/key.txt"
    else
        error "No age key at /var/lib/sops-nix/key.txt"
        echo ""
        echo "The user password is a sops secret; rebuilding without the key would"
        echo "leave the user with NO password (lockout). Retrieve it from 1Password"
        echo "(vault: Personal, item: 'sops nixos') - full details in secrets/README.md:"
        echo ""
        echo "  mkdir -p ~/.config/sops/age"
        echo "  nix-shell -p _1password-cli --run 'eval \$(op signin); op item get \"sops nixos\" --fields password --reveal' >> ~/.config/sops/age/keys.txt"
        echo "  chmod 600 ~/.config/sops/age/keys.txt"
        echo "  sudo mkdir -p /var/lib/sops-nix"
        echo "  sudo cp ~/.config/sops/age/keys.txt /var/lib/sops-nix/key.txt"
        echo "  sudo chmod 600 /var/lib/sops-nix/key.txt && sudo chown root:root /var/lib/sops-nix/key.txt"
        echo ""
        echo "Then re-run this script with --skip-clone."
        echo "(Set SKIP_SOPS_CHECK=1 to bypass this check - NOT recommended.)"
        exit 1
    fi
else
    step "7/8: Skipping sops age key check (not needed on $HOSTNAME)"
fi

# Step 8: Optionally update flake inputs (default: keep the committed,
# CI-tested flake.lock so the first build is a known-good input set)
if [[ "$UPDATE_INPUTS" == "true" ]]; then
    step "8/8: Updating flake inputs..."
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
else
    step "8/8: Keeping committed flake.lock (pass --update to update inputs)"
fi

echo ""
info "Bootstrap preparation complete!"
echo ""
echo "Next steps:"
echo "  1. Review the configuration in $CONFIG_DIR"
echo "  2. Run the rebuild script:"
if [[ "$PLATFORM" == "darwin" ]]; then
    echo "     ./scripts/nixos-rebuild.sh"
    echo "     OR"
    echo "     sudo darwin-rebuild switch --flake $CONFIG_DIR#$HOSTNAME"
else
    echo "     ./scripts/nixos-rebuild.sh"
    echo "     OR"
    echo "     sudo nixos-rebuild switch --flake $CONFIG_DIR#$HOSTNAME"
fi
echo "  3. After the first rebuild, follow the post-install checklist in BOOTSTRAP.md"
echo "     (1Password + SSH agent, Tailscale, Syncthing, git remote to SSH)"
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
