#!/usr/bin/env bash
# Prepare a fresh machine to build this checkout, then hand off to
# nixos-rebuild.sh, which owns the NixOS lockout guard and /etc/nixos upkeep.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
step() { echo -e "${CYAN}[STEP]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Prepare this machine to build the nix-config checkout this script lives in.

OPTIONS:
    -h, --help          Show this help message
    -d, --dry-run       Show what would be done without executing
    -u, --update        Update flake inputs before the initial rebuild
                        (default: build from the committed, CI-tested flake.lock)

ENVIRONMENT:
    SKIP_SOPS_CHECK=1   Skip the Darwin user age key check (not recommended)

Steps: check Nix and macOS prerequisites, enable flakes, verify this host is
in lib/hosts.nix, check the Darwin user age key, optionally update inputs,
then offer the initial rebuild. See BOOTSTRAP.md for the full runbook.
EOF
}

DRY_RUN=false
UPDATE_INPUTS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
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

CONFIG_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
if [[ "$(uname -s)" == "Darwin" ]]; then
    PLATFORM="darwin"
else
    PLATFORM="nixos"
fi
info "Detected platform: $PLATFORM; checkout: $CONFIG_DIR"
if [[ "$DRY_RUN" == "true" ]]; then
    warn "Running in DRY-RUN mode - no changes will be made"
fi

step "1/6: Checking Nix installation..."
if ! command -v nix &> /dev/null; then
    error "Nix is not installed!"
    if [[ "$PLATFORM" == "darwin" ]]; then
        echo "  Install Determinate Nix:"
        echo "  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    else
        echo "  NixOS ships Nix; for other Linux see https://nixos.org/download.html"
    fi
    exit 1
fi
success "Nix is installed: $(nix --version)"

if [[ "$PLATFORM" == "darwin" ]]; then
    step "2/6: Checking macOS prerequisites (Xcode CLT, Homebrew)..."
    PREREQS_OK=true

    # Without the Command Line Tools the /usr/bin/git shim just errors out.
    if xcode-select -p &> /dev/null; then
        success "Xcode Command Line Tools found: $(xcode-select -p)"
    else
        PREREQS_OK=false
        error "Xcode Command Line Tools are not installed"
        echo "  Install with:  xcode-select --install"
    fi

    # nix-darwin's homebrew module manages casks but does not install Homebrew.
    if command -v brew &> /dev/null || [[ -x /opt/homebrew/bin/brew || -x /usr/local/bin/brew ]]; then
        success "Homebrew found"
    else
        PREREQS_OK=false
        error "Homebrew is not installed (the darwin config manages casks through it)"
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
    step "2/6: No extra prerequisites on NixOS"
fi

step "3/6: Ensuring flakes are enabled..."
NIX_CONF="$HOME/.config/nix/nix.conf"
if [[ -f "$NIX_CONF" ]] && grep -q "experimental-features.*flakes" "$NIX_CONF"; then
    success "Flakes already enabled in $NIX_CONF"
elif [[ "$DRY_RUN" == "true" ]]; then
    info "[DRY-RUN] Would enable nix-command and flakes in $NIX_CONF"
else
    mkdir -p "$(dirname "$NIX_CONF")"
    echo "experimental-features = nix-command flakes" >> "$NIX_CONF"
    success "Enabled flakes in $NIX_CONF"
fi

step "4/6: Verifying this host has a flake configuration..."
# shellcheck source=lib/host-detect.sh
source "$CONFIG_DIR/scripts/rebuild/lib/host-detect.sh"
detect_host
info "Detected host: $HOSTNAME ($PLATFORM)"
if validate_host_configuration "$CONFIG_DIR"; then
    success "Found $HOSTNAME in lib/hosts.nix for $PLATFORM"
else
    error "Host detection did not resolve to a compatible inventory entry"
    echo "To add this machine (BOOTSTRAP.md, 'Adding a new host'):"
    echo "  1. Create machines/${HOSTNAME}.nix (and hardware config under machines/hardware/)"
    echo "  2. Add '${HOSTNAME}' to lib/hosts.nix"
    echo "  3. On Darwin, add the login mapping in scripts/rebuild/lib/host-detect.sh"
    echo "  4. Commit, then re-run this script"
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "[DRY-RUN] This would abort the bootstrap"
    else
        exit 1
    fi
fi

# NixOS's system key is checked by nixos-rebuild.sh before it switches.
# Darwin Home Manager decrypts user-scoped secrets with the user key.
if [[ "$PLATFORM" != "darwin" ]]; then
    step "5/6: The NixOS age key is checked by the rebuild before switching"
elif [[ "${SKIP_SOPS_CHECK:-0}" == "1" ]]; then
    step "5/6: Skipping user sops age key check (SKIP_SOPS_CHECK=1)"
else
    step "5/6: Checking user sops age key (needed for Home Manager secrets)..."
    USER_SOPS_KEY="$HOME/.config/sops/age/keys.txt"
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would check $USER_SOPS_KEY"
    else
        # shellcheck source=lib/sops-key.sh
        source "$CONFIG_DIR/scripts/rebuild/lib/sops-key.sh"
        export SOPS_KEY_USE_SUDO=0
        if validate_sops_key "$USER_SOPS_KEY" "$(id -u)" "$(id -g)"; then
            success "Age key is a user-owned 0600 regular file"
        else
            error "The age key is missing or has unsafe metadata: $USER_SOPS_KEY"
            echo "Expected the current user to own a non-symlink regular file with mode 0600."
            exit 1
        fi
    fi
fi

if [[ "$UPDATE_INPUTS" == "true" ]]; then
    step "6/6: Updating flake inputs..."
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would run: nix flake update"
    elif (cd "$CONFIG_DIR" && nix flake update); then
        success "Flake inputs updated"
    else
        warn "Flake update failed, continuing with the committed flake.lock"
    fi
else
    step "6/6: Keeping committed flake.lock (pass --update to update inputs)"
fi

echo ""
info "Bootstrap preparation complete. After the first rebuild, follow the"
info "post-install checklist in BOOTSTRAP.md (1Password, Tailscale, Syncthing, git remote)."
if [[ "$DRY_RUN" == "true" ]]; then
    info "[DRY-RUN] Would prompt for the initial rebuild"
    exit 0
fi
read -p "Run the initial rebuild now? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    exec "$CONFIG_DIR/scripts/rebuild/nixos-rebuild.sh" "$CONFIG_DIR"
fi
info "Run it later with: $CONFIG_DIR/scripts/rebuild/nixos-rebuild.sh"
