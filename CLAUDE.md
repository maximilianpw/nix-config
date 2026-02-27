# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A unified NixOS + nix-darwin flake managing three systems from a single codebase:
- **main-pc**: NixOS x86_64-linux desktop (AMD Ryzen, Hyprland/Wayland)
- **macbook-pro-m1**: nix-darwin aarch64-darwin (Apple Silicon, Homebrew for GUI apps)
- **wsl**: NixOS x86_64-linux under WSL (minimal, no desktop)

## Commands

```bash
make bootstrap   # Bootstrap a new system (initial setup)
make rebuild     # Apply configuration (auto-detects platform, formats with alejandra, commits, runs GC)
make build       # Build without switching
make update      # Update flake inputs
make wsl         # Build WSL tarball for import
make generations # List system generations
make rollback    # Rollback to previous generation
make info        # Show system information
```

To validate Nix syntax without building: `nix flake check --no-build`

The Nix formatter is **alejandra** (run automatically during rebuild). The rebuild script (`scripts/nixos-rebuild.sh`) expects the repo cloned at `~/nix-config`.

## Architecture

### System Builder (`lib/mksystem.nix`)

The core abstraction. Called as `mkSystem "<hostname>" { system, user, userDir?, darwin?, wsl? }` in `flake.nix`. It:
- Selects `nixosSystem` or `darwinSystem` based on the `darwin` flag
- Loads `machines/<hostname>.nix` for hardware/system config
- Loads `users/<userDir>/nixos.nix`, `darwin.nix`, or `wsl.nix` based on platform flags
- Loads `users/<userDir>/home-manager.nix` for cross-platform Home Manager config
- Wires overlays, sops-nix (NixOS only), NixOS-WSL (when `wsl = true`)
- Injects `currentSystem`, `currentSystemName`, `currentSystemUser`, `currentSystemUserDir`, `isWSL`, and `inputs` args into all modules

The `userDir` parameter allows the macOS username (`max-vev`) to differ from the repo directory (`maxpw`), so both systems share `users/maxpw/`.

### How Home Manager modules receive platform info

`mksystem.nix` imports `home-manager.nix` by calling it as a function with `{ isDarwin, isWSL, inputs, hostname }`. Modules like `xdg.nix`, `gpg.nix`, `linux-desktop.nix`, and `linux-services.nix` receive these via their own function arguments (curried imports in `home-manager.nix`). The pattern is:

```nix
# in home-manager.nix imports list:
(import ./modules/xdg.nix {inherit isDarwin isWSL hostname;})
```

### Module Layout

```
machines/           # Per-host: boot, hardware, services (main-pc.nix, macbook-pro-m1.nix, wsl.nix)
modules/
  core/             # Shared: nix-settings.nix, security.nix, sops.nix
  desktop/          # Hyprland + greetd (Linux only)
  services/         # Borg backup with retention policy
users/maxpw/
  home-manager.nix  # Cross-platform entry: imports all user modules
  nixos.nix         # NixOS user: PipeWire, networking, nix-ld, locale, Wayland, user account, imports Hyprland module
  darwin.nix        # macOS user: Homebrew casks/brews, Mac App Store apps, fonts
  wsl.nix           # WSL user: minimal config (nix-ld, fish, no desktop)
  modules/
    shells.nix      # Nushell, Fish, Bash, Zsh; all shell aliases defined here
    git.nix         # Git + Jujutsu (jj) config
    fonts.nix       # Nerd fonts + system fonts with fontconfig
    xdg.nix         # XDG config file management (Hyprland, Ghostty, waybar, kitty, yazi, etc.)
    neovim.nix      # Neovim config + LSP packages (called as function from home-manager.nix)
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

Three overlays applied in order:
1. **fenix** - Rust toolchain
2. **llm-agents** - AI CLI tools (claude-code, codex, opencode, gemini-cli, amp-cli) from the `numtide/llm-agents.nix` flake input
3. **unstable + custom** - Pulls select packages from `nixpkgs-unstable` (gh, nushell, tmuxinator, jujutsu) and defines the `helium` custom package

### Secrets

Uses sops-nix with age encryption. Keys stored in 1Password. Secrets file: `secrets/secrets.yaml`. Only used on NixOS (for user password and borg backup passphrase).

### XDG config management (`users/maxpw/modules/xdg.nix`)

Dotfiles for desktop apps (Hyprland, waybar, rofi, ghostty, kitty, yazi, etc.) live as plain files under `users/maxpw/` and are symlinked into `~/.config/` via `xdg.configFile`. The `symlinkDir` helper auto-links all files in a directory. Hyprland configs use per-host overrides via the `hostname` argument (e.g., lock screen only on non-main-pc hosts).

## Conventions

- **Nix formatting**: alejandra (no tabs, no trailing whitespace).
- **Adding packages**: User packages go in `users/maxpw/modules/packages/` split by category. System packages go in the relevant machine file.
- **Platform conditionals**: OS-specific config lives in `nixos.nix`/`darwin.nix`/`wsl.nix` per user, not behind `if` statements in shared modules. For Home Manager modules, use `isDarwin`/`isWSL`/`hostname` arguments passed through from `home-manager.nix`.
- **New modules**: Import them in the appropriate aggregator (`home-manager.nix`, `nixos.nix`, or `darwin.nix`). The `mksystem.nix` builder handles wiring.
- **Nixpkgs channels**: Stable is `nixpkgs` (25.11). For bleeding-edge packages, add them to the unstable overlay in `flake.nix`. To add a new unstable package: in the third overlay in `flake.nix`, add `<pkg> = unstable.<pkg>;` alongside the existing entries (gh, nushell, etc.), then reference `pkgs.<pkg>` in the relevant module.
- **Shell aliases**: All aliases are centralized in `users/maxpw/modules/shells.nix`. The `nr` alias runs `make -C ~/nix-config rebuild`.
- **macOS GUI apps**: Managed via Homebrew casks in `darwin.nix`, not Nix packages. Homebrew `onActivation.cleanup = "zap"` removes anything not declared.

## Gotchas

- **Never bump `stateVersion`**: `system.stateVersion` and `home.stateVersion` must stay at their initial install values. They control state migration, not the package set version.
- **Hyprland comes from upstream flake input**, not nixpkgs. Check the `hyprland` input in `flake.nix` when debugging Hyprland issues.
- **macOS Nix daemon**: Managed by the Determinate installer. `nix.enable = false` in `macbook-pro-m1.nix` — don't set it to `true`.
- **Rebuild auto-commits**: `make rebuild` stages tracked-file changes, commits with a generation message, and runs GC. Untracked new files are not auto-staged. Don't make unrelated uncommitted changes before rebuilding.
