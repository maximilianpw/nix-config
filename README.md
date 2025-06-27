# NixOS VM Configuration

A comprehensive NixOS configuration for virtual machines with modular design and multi-platform support.

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
- ✅ **Type Safety**: Better validation and error handling

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
- ✅ **Guest Tools**: Proper VMware tools integration
- ✅ **Network Optimization**: VMware-specific settings

## 📦 What's Included

### System Packages
- **Core Tools**: git, curl, wget, vim, neofetch
- **Development**: rustup, nodejs, python3, go, openjdk  
- **Shell**: zsh with advanced configuration
- **Editor**: neovim as default editor

### Desktop Environment
- **Display**: X11 with GNOME
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
