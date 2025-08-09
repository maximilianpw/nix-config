# Nix Configuration

Unified NixOS + macOS (nix-darwin) flake with a modular layout, Home Manager integration, and a VM target (`vm-aarch64`).

## 🏗️ Architecture

This configuration uses a modular approach with shared common modules and host-specific configurations:

```
├── flake.nix                    # Main flake configuration
├── hosts/                      # Host-specific configurations
│   ├── default/                # Standard x86_64 VM
│   ├── bigboy/                 # High-performance VM with NVIDIA
│   └── mac/                    # ARM64 VM for VMware Fusion
├── modules/
│   ├── nixos/                  # System-level modules
│   │   ├── common.nix          # Shared system configuration
│   │   ├── vm-common.nix       # VM-specific optimizations
│   │   ├── vmware.nix          # VMware Fusion optimizations
│   │   └── nvidia.nix          # NVIDIA graphics configuration
│   └── home-manager/           # User-level modules
│       ├── dotfiles.nix        # Main entry point
│       ├── development.nix     # Programming tools
│       ├── terminal.nix        # Shell and terminal setup
│       ├── neovim.nix          # Neovim configuration
│       └── fonts.nix           # Font management
└── scripts/
    └── nixos-rebuild.sh        # Intelligent rebuild script
```

## 🚀 Quick Start

### 1. Choose Your Host Configuration

- **default**: Standard VM for general use
- **bigboy**: High-performance VM with NVIDIA support
- **mac**: ARM64 VM optimized for VMware Fusion on Mac

### 2. Rebuild Your System

```bash
# Using the improved rebuild script (recommended)
./scripts/nixos-rebuild.sh <hostname>

# Or manually:
sudo nixos-rebuild switch --flake ./#<hostname>

# Examples:
./scripts/nixos-rebuild.sh default
./scripts/nixos-rebuild.sh bigboy  
./scripts/nixos-rebuild.sh mac
```

## 🎯 Key Improvements Made

### System Architecture
- ✅ **Modular Design**: Eliminated code duplication with shared modules
- ✅ **Host-Specific Configs**: Each VM has minimal, focused configuration
- ✅ **Modern NixOS**: Updated from 23.11 to 24.05 for better support
- ✅ **Option Assertions & Types**: Stronger validation and clearer errors

### VM Optimizations
- ✅ **Performance Tuning**: VM-specific kernel parameters
- ✅ **Resource Management**: Intelligent memory and I/O scheduling  
- ✅ **Boot Optimization**: Faster boot times
- ✅ **Network Tuning**: Proper VM network interface handling

### Development Experience
- ✅ **Enhanced Rebuild Script**: Better error handling and validation
- ✅ **Git Integration**: Automatic commits on successful builds
- ✅ **Garbage Collection**: Automatic cleanup of old generations
- ✅ **Development Shell**: Easy environment for config development

### NVIDIA Configuration (bigboy host)
- ✅ **Stable Drivers**: Switched from beta to stable drivers
- ✅ **Better Power Management**: Configurable options
- ✅ **Offload Commands**: Easy NVIDIA offloading
- ✅ **Gaming Support**: Steam integration

### VMware Integration (mac host)  
- ✅ **ARM64 Optimizations**: Specific tuning for Apple Silicon
- ✅ **Guest Tools**: Proper VMware tools integration (`open-vm-tools` service enabled)
- ✅ **Network Optimization**: VMware-specific settings

## 📦 What's Included

### System Packages
- **Core Tools**: git, curl, wget, vim, neofetch
- **Development**: rustup, nodejs, python3, go, openjdk  
- **Shell**: zsh with advanced configuration
- **Editor**: neovim as default editor

### Desktop Environment
- **Display**: GNOME (Wayland by default; forced to Xorg if configured)
- **Audio**: PipeWire for modern audio
- **Fonts**: Comprehensive collection including Nerd Fonts
- **Input**: Colemak keyboard layout

## 🛠️ Usage

### Rebuild Your System
```bash
# Use the improved script (recommended)
./scripts/nixos-rebuild.sh default

# The script will:
# 1. Validate your flake configuration
# 2. Format Nix files with alejandra
# 3. Show what changed
# 4. Build and apply the configuration
# 5. Commit changes to git
# 6. Clean up old generations
```

### Manual Commands
```bash
# Check flake validity
nix flake check

# Build without applying
nixos-rebuild dry-run --flake ./#hostname

# Apply configuration
sudo nixos-rebuild switch --flake ./#hostname
```

## 🔧 Customization

### Adding New Hosts
1. Create directory in `hosts/`
2. Add minimal configuration.nix 
3. Update flake.nix
4. Use shared modules for common functionality

### Modifying Configuration
- **System-wide**: Edit `modules/nixos/common.nix`
- **User-level**: Edit `modules/home-manager/` files
- **VM-specific**: Modify `modules/nixos/vm-common.nix`

## 🐛 Troubleshooting

```bash
# Check system logs
journalctl -xe

# View rebuild logs  
tail -f ~/Nix-Config/nixos-switch.log

# Test configuration
nix flake check
```

---

**Previous command**: `sudo nixos-rebuild switch --flake ./#default` (still works but use the script instead)

---

## 🆕 New `vm-aarch64` VM Provisioning (One-Time Setup)

> **Note:** If you use the **graphical NixOS installer (Calamares)**, it will partition, format, and mount automatically. In that case, you can skip steps 2–3 below and go straight to installing from your flake. These manual steps are for the **minimal CLI ISO**.

You only perform the disk prep + `nixos-install` once. After first boot, just run the rebuild script (it builds implicitly). The explicit `nix build` of the toplevel derivation is optional.

### 1. Boot Live ISO (ARM64)
Attach the aarch64 NixOS minimal ISO in VMware Fusion (Apple Silicon) and boot.

### 2. Partition & Format (Minimal ISO Only)
Adjust device names (`/dev/sda`, `/dev/vda`, `/dev/nvme0n1`) as needed.
```bash
lsblk
gdisk /dev/sda   # create EFI (type EF00) + root (type 8300)
mkfs.vfat -F32 -n boot /dev/sda1
mkfs.ext4 -L nixos /dev/sda2
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
```

### 3. Fetch Config (Optional for Minimal ISO)
If you want the repo present on first boot:
```bash
mkdir -p /mnt/home/maxpw
cd /mnt/home/maxpw
nix-shell -p git --command 'git clone https://github.com/<your-user>/nix-config'
ln -s /home/maxpw/nix-config /mnt/etc/nixos
```
Otherwise, skip this and clone after your first boot.

### 4. (Optional) Preflight Build
```bash
nix build /mnt/etc/nixos#nixosConfigurations.vm-aarch64.config.system.build.toplevel
```
Use this only if you want early feedback. `nixos-install` will build anyway.

### 5. Install
Local flake:
```bash
nixos-install --flake /mnt/etc/nixos#vm-aarch64
```
Remote flake:
```bash
nixos-install --flake github:<your-user>/nix-config#vm-aarch64
```
Then reboot.

### 6. Routine Updates (After Reboot)
```bash
cd ~/nix-config
./scripts/nixos-rebuild.sh
```
The script auto-detects user `maxpw` and selects `vm-aarch64`.

### When To Use Which Command
| Scenario | Command |
|----------|---------|
| One-time install (local) | nixos-install --flake /mnt/etc/nixos#vm-aarch64 |
| One-time install (remote) | nixos-install --flake github:<you>/nix-config#vm-aarch64 |
| Routine update | ./scripts/nixos-rebuild.sh |
| Build only | nix build .#nixosConfigurations.vm-aarch64.config.system.build.toplevel |
| Dry run | nixos-rebuild dry-run --flake .#vm-aarch64 |

### VMware ARM64 Tips
- Use `boot.loader.systemd-boot.enable = true;` and `boot.loader.efi.canTouchEfiVariables = true;`
- Enable `services.open-vm-tools.enable = true;` for copy/paste, drag-and-drop, and guest features.
- Device name may differ by disk type (`vda`, `sda`, or `nvme0n1`).

### Troubleshooting
```bash
journalctl -b -xe | less
journalctl -b -1 -xe
nix flake metadata
sudo nix-store --verify --check-contents
```

### FAQ
Q: Should I run `nix build` every time before switching?  
A: No. `nixos-rebuild switch --flake` (and the provided script) already builds the system derivation. Use `nix build` only for CI, debugging, or benchmarking.
