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
make rebuild     # Apply configuration (auto-detects platform, formats with alejandra, switches via nh with a generation diff, cleans old generations)
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

`mksystem.nix` passes `isDarwin`, `isWSL`, `hostname`, and `inputs` to all Home Manager modules via `home-manager.extraSpecialArgs`. Modules receive these as regular function arguments:

```nix
# any HM module can destructure these directly:
{ isDarwin, isWSL ? false, hostname, pkgs, lib, ... }: { ... }
```

### Module Layout

```
machines/           # Per-host: boot, hardware, services (main-pc.nix, macbook-pro-m1.nix, wsl.nix)
homelab/            # main-pc self-hosted services exposed through Cloudflare Tunnel
modules/
  core/             # Shared: nix-settings.nix, security.nix, sops.nix, shells.nix (login shells)
  desktop/          # Hyprland + greetd (Linux only)
  fleet/            # Remote dev fleet: NixOS Tailscale/mosh/tmux + HM SSH/fleet CLI
  services/         # Borg backup with retention policy
users/maxpw/
  home-manager.nix  # Cross-platform entry: imports all user modules
  nixos.nix         # NixOS user: PipeWire, networking, nix-ld, locale, Wayland, user account, imports Hyprland module
  darwin.nix        # macOS user: Homebrew casks/brews, Mac App Store apps, fonts
  wsl.nix           # WSL user: minimal config (nix-ld, fish, no desktop)
  modules/
    shells.nix      # Nushell, Fish, Bash, Zsh; all shell aliases defined here
    git.nix         # Git + Jujutsu (jj) config
    vcs/jujutsu.nix # Jujutsu config
    agent-tools.nix # LLM agent CLIs + aliases
    t3code-server.nix # T3 Chat code server integration
    fonts.nix       # Nerd fonts + system fonts with fontconfig
    xdg.nix         # XDG config file management (Hyprland, Ghostty, waybar, kitty, yazi, etc.)
    neovim.nix      # Neovim config + LSP packages (called as function from home-manager.nix)
    gpg.nix         # GPG agent (Linux only)
    syncthing.nix   # User-level Syncthing config
    himalaya.nix    # Email client config
    tmux.nix        # Tmux with plugins
    linux-services.nix  # Polkit agent, cursor settings
    packages/
      dev-tools.nix       # Languages, formatters, cloud tools
      terminal-tools.nix  # CLI utilities (bat, eza, fzf, ripgrep, etc.)
      linux-desktop.nix   # Wayland/GUI apps (Ghostty, rofi, waybar, etc.)
      custom-scripts.nix  # Personal helper scripts
packages/           # Custom package definitions (helium, obsidian, t3code, coderabbit)
secrets/            # sops-nix encrypted secrets (age encryption, key in 1Password)
```

### Homelab Services

`homelab/` is imported by `machines/main-pc.nix` and aggregates the services that run on main-pc. `homelab/cloudflared.nix` defines the Cloudflare tunnel ingress for those services, secrets are managed through sops-nix, and most service endpoints bind to `127.0.0.1`.

Fleet remote-development usage and implementation notes live in `modules/fleet/README.md`; implementation is split between `modules/fleet/home-manager.nix` and `modules/fleet/nixos.nix`.

### Overlays (defined in `flake.nix`)

Three overlays applied in order:
1. **fenix** - Rust toolchain
2. **llm-agents** - AI CLI tools (claude-code, codex, opencode, amp-cli, pi, skills, hunkdiff, agent-browser) from the `numtide/llm-agents.nix` flake input
3. **unstable + custom** - Exposes the full unstable channel as `pkgs.unstable`, pulls select packages from `nixpkgs-unstable` (jujutsu, zig), and defines the custom packages (helium, obsidian, t3code, coderabbit)

### Secrets

Uses sops-nix with age encryption. Keys stored in 1Password. Secrets file: `secrets/secrets.yaml`. Only used on NixOS (for user password and borg backup passphrase).

### XDG config management (`users/maxpw/modules/xdg.nix`)

Dotfiles for desktop apps (Hyprland, waybar, rofi, ghostty, kitty, yazi, etc.) live as plain files under `users/maxpw/` and are symlinked into `~/.config/` via `xdg.configFile`. The `symlinkDir` helper auto-links all files in a directory. Hyprland configs use per-host overrides via the `hostname` argument (e.g., lock screen only on non-main-pc hosts).

## Conventions

- **Nix formatting**: alejandra (no tabs, no trailing whitespace).
- **Adding packages**: User packages go in `users/maxpw/modules/packages/` split by category. System packages go in the relevant machine file.
- **Structural code search**: Use `rg` for literal text search and file discovery. Use `ast-grep` (`sg`) for syntax-aware search, linting, and mechanical refactors where whitespace, formatting, or nesting should not matter. For broad rewrites, run search-only first, inspect matches, then apply rewrites and review the diff.
- **Platform conditionals**: Config that diverges substantially per-OS lives in `nixos.nix`/`darwin.nix`/`wsl.nix` per user, not behind `if` statements in large shared modules. Small cross-platform Home Manager modules that are imported unconditionally (e.g. `gpg.nix`, `linux-services.nix`, `linux-desktop.nix`, `xdg.nix`) may instead guard their platform-specific bits internally using the `isDarwin`/`isWSL`/`isLinuxDesktop`/`hostname` arguments injected by `mksystem.nix` — these flags are always passed, so destructure them directly without fallback defaults.
- **New modules**: Import them in the appropriate aggregator (`home-manager.nix`, `nixos.nix`, or `darwin.nix`). The `mksystem.nix` builder handles wiring.
- **Nixpkgs channels**: Stable is `nixpkgs` (26.05). For bleeding-edge packages, add them to the unstable overlay in `flake.nix`. To add a new unstable package: in the third overlay in `flake.nix`, add `<pkg> = unstable.<pkg>;` alongside the existing entries (jujutsu, zig), then reference `pkgs.<pkg>` in the relevant module. For a one-off, `pkgs.unstable.<pkg>` also works without touching the overlay.
- **Shell aliases**: All aliases are centralized in `users/maxpw/modules/shells.nix`. The `nr` alias runs `make -C ~/nix-config rebuild`.
- **Shell**: Nushell is the primary interactive shell. When generating commands, scripts, or one-liners for the user to run, prefer Nushell's structured-data pipelines over POSIX text-munging tools. Substitute `grep` → `where`/`find`/`str contains`, `awk`/`cut` → `get`/`select`/`columns`, `sed` → `str replace`, `wc -l` → `length`, `sort | uniq -c` → `group-by | transpose`, `xargs` → `each`, `jq` → native `from json` + `get`. Reach for the POSIX tool only when the target is a non-Nushell context (a Bash script, CI step, Makefile, README example, or a tool that shells out via `/bin/sh`).
- **macOS GUI apps**: Managed via Homebrew casks in `darwin.nix`, not Nix packages. Homebrew `onActivation.cleanup = "zap"` removes anything not declared.

## Gotchas

- **Never bump `stateVersion`**: `system.stateVersion` and `home.stateVersion` must stay at their initial install values. They control state migration, not the package set version.
- **Hyprland comes from upstream flake input**, not nixpkgs. Check the `hyprland` input in `flake.nix` when debugging Hyprland issues.
- **macOS Nix daemon**: Managed by the Determinate installer. `nix.enable = false` in `macbook-pro-m1.nix` — don't set it to `true`.
- **Rebuild does NOT auto-commit**: `make rebuild` formats with alejandra, switches via nh (which prints a package-level generation diff), and cleans old generations (`nh clean all --keep 5 --keep-since 30d`) — but always leaves the repo uncommitted. Commit manually; the pre-commit hook lints on commit.
- **Darwin Nix settings live in /etc/nix/nix.custom.conf**: because `nix.enable = false` on macOS, nix-darwin ignores `nix.settings`. Caches/trusted-users for the Mac are managed via `environment.etc."nix/nix.custom.conf"` in `machines/macbook-pro-m1.nix`.
