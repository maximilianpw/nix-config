# NixOS Configuration Integration Summary

This document provides an overview of the modular NixOS configuration structure and what modules each host uses.

## 📁 Configuration Structure

```
Nix-Config/
├── flake.nix                    # Main flake configuration
├── hosts/                      # Host-specific configurations
│   ├── default/                # Standard x86_64 VM
│   ├── bigboy/                 # Gaming/workstation x86_64
│   └── mac/                    # ARM64 VMware Fusion VM
└── modules/
    ├── home-manager/           # User environment modules
    │   ├── dotfiles.nix        # Symlinks to dotfiles
    │   ├── terminal.nix        # Terminal tools (no config)
    │   ├── neovim.nix         # Language servers (no config)
    │   ├── development.nix     # Development tools
    │   └── fonts.nix          # Font packages
    └── nixos/                  # System-level modules
        ├── common.nix          # Shared system settings
        ├── vm-common.nix       # VM optimizations
        ├── vmware.nix          # VMware-specific settings
        └── nvidia.nix          # NVIDIA GPU configuration
```

## 🏠 Host Configurations

### 🖥️ `default` (Standard x86_64 VM)
**Purpose**: Basic NixOS VM for development and testing

**System Modules Used**:
- `modules/nixos/common.nix` - Base system configuration
- `modules/nixos/vm-common.nix` - VM optimizations
- `modules/nixos/vmware.nix` - VMware guest tools

**Home Manager Modules Used**:
- `modules/home-manager/dotfiles.nix` - Symlinks to dotfiles

**Key Features**:
- Standard GNOME desktop environment
- VMware guest additions for x86_64
- Basic development tools via dotfiles

---

### 🎮 `bigboy` (Gaming/Workstation x86_64)
**Purpose**: High-performance workstation with NVIDIA GPU support

**System Modules Used**:
- `modules/nixos/common.nix` - Base system configuration
- `modules/nixos/nvidia.nix` - NVIDIA GPU drivers and settings

**Home Manager Modules Used**:
- `modules/home-manager/dotfiles.nix` - Symlinks to dotfiles

**Key Features**:
- NVIDIA GPU support with proprietary drivers
- Gaming optimizations
- Enhanced hardware support
- Colemak keyboard layout
- Additional development packages (rustup, gh, alejandra)

**Host-Specific Overrides**:
- Time zone: `Europe/Paris`
- Locale: `en_GB.UTF-8` with French regional settings
- Keyboard: US layout with Colemak variant
- GRUB bootloader on `/dev/sda`

---

### 🍎 `mac` (ARM64 VMware Fusion VM)
**Purpose**: ARM64-compatible VM for macOS VMware Fusion

**System Modules Used**:
- `modules/nixos/common.nix` - Base system configuration
- `modules/nixos/vm-common.nix` - VM optimizations (with ARM64 checks)

**Home Manager Modules Used**:
- `modules/home-manager/dotfiles.nix` - Symlinks to dotfiles

**Key Features**:
- ARM64 (aarch64-linux) architecture support
- VMware Fusion compatibility
- ARM-optimized kernel parameters
- UEFI boot with EFI variable support

**Host-Specific Overrides**:
- ARM64-specific kernel parameters
- VMware guest tools disabled (x86-only package conflicts)
- `open-vm-tools` package for ARM64 VMware support
- UEFI bootloader configuration

**ARM64 Optimizations**:
```nix
boot.kernelParams = [
  "elevator=mq-deadline"           # Better I/O for ARM64
  "transparent_hugepage=madvise"   # Conservative memory management
  "mitigations=auto"               # Platform-appropriate security
];
```

## 🏗️ Module Architecture

### System Modules (`modules/nixos/`)

#### `common.nix`
**Shared across**: All hosts
**Provides**:
- User account definition (`maxpw`)
- Networking (NetworkManager)
- Locale and timezone settings (with `lib.mkDefault`)
- Desktop environment (GNOME + GDM)
- Audio (PipeWire)
- Basic system packages
- SSH server
- Nix flakes support

#### `vm-common.nix`
**Shared across**: `default`, `mac`
**Provides**:
- VM-specific kernel modules
- Serial console support
- Guest services (SPICE, QEMU)
- VMware guest tools (with x86_64 platform check)
- VM networking optimizations
- Reduced journal sizes for VMs

#### `vmware.nix`
**Used by**: `default` only
**Provides**:
- VMware-specific video drivers (x86_64 only)
- VMware display optimizations
- Enhanced VMware guest support

#### `nvidia.nix`
**Used by**: `bigboy` only
**Provides**:
- NVIDIA proprietary drivers
- OpenGL with 32-bit support
- NVIDIA-specific optimizations
- Hardware acceleration

### Home Manager Modules (`modules/home-manager/`)

#### `dotfiles.nix`
**Used by**: All hosts
**Provides**:
- Symlink: `~/dotfiles/.config` → `~/.config`
- Symlink: `~/dotfiles/.zshrc` → `~/.zshrc`
- **Note**: All shell and editor configuration is handled by dotfiles, not Nix

#### `terminal.nix` (Available for optional import)
**Provides**: Terminal tools without configuration
- Shell utilities (ripgrep, fzf, eza, bat, etc.)
- System tools (htop, neofetch, curl, etc.)
- **Usage**: Add to imports in host-specific home.nix if needed

#### `neovim.nix` (Available for optional import)
**Provides**: Language servers and tools for Neovim
- LSPs (clangd, gopls, pyright, rust-analyzer, etc.)
- Formatters and linters
- Tree-sitter parsers
- **Usage**: Add to imports in host-specific home.nix if needed

#### `development.nix` (Available for optional import)
**Provides**: Development tools and programming languages
- Compilers (gcc, clang, rustc, etc.)
- Package managers (npm, pip, cargo, etc.)
- **Usage**: Add to imports in host-specific home.nix if needed
- **Note**: May conflict with neovim.nix if both import compilers

## 🔧 Configuration Philosophy

### ✅ What Nix Manages
- System packages and services
- User account and system settings
- Hardware-specific configurations
- Language servers and development tools

### 🚫 What Dotfiles Manage
- Shell configuration (zsh, starship, aliases)
- Editor configuration (Neovim plugins and settings)
- Terminal emulator settings
- Application-specific configurations

### 🎯 Benefits
- **Modular**: Easy to add/remove features per host
- **Portable**: Dotfiles work across any system
- **Maintainable**: Clear separation of concerns
- **Platform-aware**: ARM64 and x86_64 compatibility

## 🚀 Usage

### Rebuild a specific host:
```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

### Available hosts:
- `default` - Standard x86_64 VM
- `bigboy` - Gaming workstation with NVIDIA
- `mac` - ARM64 VMware Fusion VM

### Validate configuration:
```bash
nix flake check
```

## 📝 Notes

- All hosts use `home-manager` for user environment management
- Platform-specific packages are guarded with `lib.mkIf (pkgs.stdenv.isx86_64)`
- Dotfiles repository should be cloned to `~/dotfiles` for symlinks to work
- System state versions are host-specific (`23.11` for mac, `24.05` default)
