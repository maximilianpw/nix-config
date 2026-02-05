# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A unified NixOS + nix-darwin flake managing two systems from a single codebase:
- **main-pc**: NixOS x86_64-linux desktop (AMD Ryzen, Hyprland/Wayland)
- **macbook-pro-m1**: nix-darwin aarch64-darwin (Apple Silicon, Homebrew for GUI apps)

## Commands

```bash
make rebuild     # Apply configuration (auto-detects platform, formats with alejandra, commits)
make check       # Validate flake (nix flake check)
make update      # Update flake inputs
make build       # Build without switching
make gc          # Garbage collect old generations
make generations # List system generations
make rollback    # Rollback to previous generation
```

The Nix formatter is **alejandra** (run automatically during rebuild).

## Architecture

### System Builder (`lib/mksystem.nix`)

The core abstraction. Called as `mkSystem "<hostname>" { system, user, userDir?, darwin? }` in `flake.nix`. It:
- Selects `nixosSystem` or `darwinSystem` based on the `darwin` flag
- Loads `machines/<hostname>.nix` for hardware/system config
- Loads `users/<userDir>/nixos.nix` or `users/<userDir>/darwin.nix` for OS-level user config
- Loads `users/<userDir>/home-manager.nix` for cross-platform Home Manager config
- Wires overlays, sops-nix (NixOS only), and injects `currentSystem*` args into all modules

The `userDir` parameter allows the macOS username (`max-vev`) to differ from the repo directory (`maxpw`), so both systems share `users/maxpw/`.

### Module Layout

```
machines/           # Per-host: boot, hardware, services (main-pc.nix, macbook-pro-m1.nix)
modules/
  core/             # Shared: nix-settings.nix, security.nix, sops.nix
  desktop/          # Hyprland + greetd (Linux only)
  services/         # Borg backup with retention policy
users/maxpw/
  home-manager.nix  # Cross-platform entry: imports all user modules, configures Neovim + LSPs
  nixos.nix         # NixOS user: PipeWire, networking, nix-ld, locale, Wayland
  darwin.nix        # macOS user: Homebrew casks/brews, Mac App Store apps, fonts
  modules/
    shells.nix      # Fish (primary), Bash, Zsh, Nushell; all shell aliases
    git.nix         # Git + Jujutsu (jj) config
    fonts.nix       # Nerd fonts + system fonts with fontconfig
    xdg.nix         # XDG config file management (Hyprland, Ghostty, waybar, etc.)
    gpg.nix         # GPG agent (Linux only)
    tmux.nix        # Tmux with plugins
    linux-services.nix  # Polkit agent, cursor settings
    packages/
      dev-tools.nix       # Languages, formatters, cloud tools
      terminal-tools.nix  # CLI utilities (bat, eza, fzf, ripgrep, etc.)
      linux-desktop.nix   # Wayland/GUI apps (Ghostty, rofi, waybar, etc.)
packages/           # Custom package definitions (helium.nix - AppImage wrapper)
secrets/            # sops-nix encrypted secrets (age encryption, key in 1Password)
```

### Overlays (defined in `flake.nix`)

Four overlays applied in order: fenix (Rust), claude-code, jujutsu, and a custom overlay that pulls select packages from `nixpkgs-unstable` and defines the `helium` package.

### Secrets

Uses sops-nix with age encryption. Keys stored in 1Password. Secrets file: `secrets/secrets.yaml`. Only used on NixOS (for user password and borg backup passphrase).

## Conventions

- **Nix formatting**: alejandra (no tabs, no trailing whitespace)
- **Adding packages**: User packages go in `users/maxpw/modules/packages/` split by category. System packages go in the relevant machine file.
- **Platform conditionals**: OS-specific config lives in `nixos.nix`/`darwin.nix` per user, not behind `if` statements in shared modules. For Home Manager, use the `isDarwin` argument passed to `home-manager.nix`.
- **New modules**: Import them in the appropriate aggregator (`home-manager.nix`, `nixos.nix`, or `darwin.nix`). The `mksystem.nix` builder handles wiring.
- **Nixpkgs channels**: Stable is `nixpkgs` (25.11). For bleeding-edge packages, add them to the unstable overlay in `flake.nix`.
