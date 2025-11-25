# Bootstrap Guide

This guide explains how to set up nix-config on a new system.

## Prerequisites

### For NixOS
NixOS comes with Nix pre-installed, so you're ready to go!

### For macOS
Install Nix using the Determinate Nix Installer (recommended):
```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### For other Linux distributions
Follow the official Nix installation guide at https://nixos.org/download.html

## Quick Start

### Option 1: Using the bootstrap script (Recommended)

1. Clone this repository:
```bash
git clone <your-repo-url> ~/nix-config
cd ~/nix-config
```

2. Run the bootstrap script:
```bash
./scripts/bootstrap.sh
```

The bootstrap script will:
- Check for Nix installation
- Enable flakes if not already enabled
- Set up `/etc/nixos` symlink (NixOS only)
- Update flake inputs
- Optionally run the initial system rebuild

### Option 2: Using Make commands

If you have `make` installed:

```bash
# Clone the repository
git clone <your-repo-url> ~/nix-config
cd ~/nix-config

# Run bootstrap
make bootstrap

# Or see what it would do first
make bootstrap-dry-run
```

### Option 3: Manual setup

If you prefer to set things up manually:

1. Clone the repository:
```bash
git clone <your-repo-url> ~/nix-config
cd ~/nix-config
```

2. Enable flakes (if not already enabled):
```bash
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
```

3. For NixOS, create the `/etc/nixos` symlink:
```bash
sudo ln -sfn ~/nix-config /etc/nixos
```

4. Update flake inputs:
```bash
nix flake update
```

5. Build and apply the configuration:
```bash
# For NixOS
sudo nixos-rebuild switch --flake .#main-pc

# For macOS
sudo darwin-rebuild switch --flake .#macbook-pro-m1
```

## Customization

Before running the initial rebuild, you should customize the configuration for your system:

### 1. Update host configuration

Edit the appropriate machine configuration:
- NixOS: `machines/main-pc.nix`
- macOS: `machines/macbook-pro-m1.nix`

### 2. Update user configuration

Edit the user configuration in `users/maxpw/`:
- Update username and personal settings
- Customize shell configuration
- Adjust package selections

### 3. Update flake.nix

Edit `flake.nix` to add your system:

```nix
outputs = {
  # Add your system configuration
  nixosConfigurations.your-hostname = mkSystem "your-hostname" {
    system = "x86_64-linux";
    user = "your-username";
  };
};
```

### 4. Update the rebuild script

Edit `scripts/nixos-rebuild.sh` to add your hostname mapping:

```bash
USER_HOST_MAP=(
  ["your-username"]="your-hostname"
)
```

### 5. Update the bootstrap script

Edit `scripts/bootstrap.sh` and update the git clone URL:

```bash
git clone https://github.com/yourusername/nix-config.git $CONFIG_DIR
```

## Available Make Commands

After bootstrap, you can use these convenient commands:

```bash
make help              # Show all available commands
make rebuild           # Rebuild system configuration
make check             # Validate flake configuration
make update            # Update flake inputs
make format            # Format Nix files with alejandra
make diff              # Show uncommitted changes
make gc                # Run garbage collection (30 days)
make gc-aggressive     # Delete all old generations
make build             # Build without switching
make generations       # List system generations
make rollback          # Rollback to previous generation
make dev               # Enter development shell
make info              # Show system information
```

## Troubleshooting

### Flakes not working
Ensure experimental features are enabled:
```bash
nix-shell -p nix-info --run "nix-info -m"
```

### Permission issues on NixOS
Make sure you're using `sudo` for system-level operations:
```bash
sudo nixos-rebuild switch --flake .#main-pc
```

### /etc/nixos is a directory
If `/etc/nixos` exists as a directory (not a symlink), back it up first:
```bash
sudo mv /etc/nixos /etc/nixos.backup
sudo ln -sfn ~/nix-config /etc/nixos
```

### Build failures
Check the error logs:
```bash
# View recent errors
cat ~/nix-config/nixos-switch.log

# Validate configuration
nix flake check
```

## Next Steps

After successful bootstrap:

1. Review and customize your configuration
2. Run `make rebuild` to apply changes
3. Set up secrets management (see `secrets/README.md`)
4. Configure git to use your credentials
5. Install additional packages as needed

## Support

For issues or questions:
- Check the main [README.md](README.md) for configuration details
- Review flake structure in `lib/mksystem.nix`
- Consult the NixOS manual: https://nixos.org/manual/
- For nix-darwin: https://github.com/LnL7/nix-darwin
