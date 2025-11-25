# Nix-Config

Unified NixOS + macOS (nix-darwin) flake with Home Manager, Hyprland/GNOME modules, and a smart rebuild script.

## Repository layout

```
.
├── flake.nix                # Main flake: inputs, overlays, and outputs
├── flake.lock
├── lib/
│   └── mksystem.nix         # mkSystem builder (NixOS & Darwin + Home Manager)
├── machines/
│   ├── macbook-pro-m1.nix   # macOS (nix-darwin) host
│   ├── main-pc.nix          # NixOS desktop (Ryzen + Hyprland)
│   ├── wsl.nix              # NixOS-WSL base
│   └── hardware/
│       └── main-pc.nix      # Hardware profile for main-pc
├── modules/
│   ├── core/
│   │   ├── nix-settings.nix # Shared Nix settings (experimental-features, flakes)
│   │   └── security.nix     # Security defaults (SSH, polkit, rtkit)
│   └── desktop/
│       ├── gnome.nix        # GNOME on Wayland via GDM (+extensions, portals)
│       └── hyprland.nix     # Hyprland from upstream flake (+portals, env)
├── packages/
│   └── helium.nix           # Custom package: Helium floating browser
├── scripts/
│   └── nixos-rebuild.sh     # Smart rebuild script (Darwin/NixOS autodetect)
├── users/
│   └── maxpw/
│       ├── home-manager.nix # Main Home Manager config (Linux & macOS)
│       ├── nixos.nix        # NixOS user/system module
│       ├── darwin.nix       # nix-darwin user/system module for macbook-pro-m1
│       ├── fonts.nix        # Fonts (Nerd Fonts + defaults, fontconfig)
│       ├── neovim.nix       # Neovim configuration with LSPs
│       ├── packages/
│       │   ├── dev-tools.nix      # Development packages (languages, tools)
│       │   ├── terminal-tools.nix # CLI utilities and terminal tools
│       │   └── linux-desktop.nix  # Linux GUI apps and Wayland tools
│       ├── zshrc            # zsh init (zinit + plugins)
│       ├── config.fish      # fish init (ssh-agent, Homebrew, starship)
│       ├── config.nu        # nushell init (env, direnv hook, helpers)
│       ├── ghostty.linux    # Ghostty config (Linux); linked by HM
│       ├── RectangleConfig.json # Rectangle.app settings (macOS); linked by HM
│       └── [various configs] # Hyprland, waybar, rofi, etc.
├── INTEGRATION_SUMMARY.md   # High-level integration notes (may be older)
├── nixos-switch.log         # Last rebuild log (script output)
└── "vscode config.code-profile" # VS Code profile export (settings/extensions)
```

## Flake overview

- Inputs: nixpkgs 25.05, nixpkgs-unstable (select pkgs), home-manager 25.05, nix-darwin 25.05, Hyprland, nix-snapd, NixOS-WSL.
- Overlay: exposes `unstable` and selects newer packages (gh, claude-code, nushell).
- mkSystem (`lib/mksystem.nix`):
  - Picks nixosSystem or darwinSystem.
  - Adds nix-snapd on Linux; NixOS-WSL when `wsl = true`.
  - Integrates Home Manager at `home-manager.users.<user>` using `users/<userDir>/home-manager.nix`.
  - Injects convenience args: `currentSystem*`, `isWSL`, `inputs`.
- Outputs:
  - `nixosConfigurations.main-pc` (x86_64-linux; user: `maxpw`).
  - `darwinConfigurations.macbook-pro-m1` (aarch64-darwin; login `max-vev`, userDir `maxpw`).
  - `devShells` for aarch64/x86_64 Linux and aarch64 Darwin.

## What each file/module does

- lib/mksystem.nix
  - Chooses NixOS or Darwin system function, wires Home Manager, optional WSL & snapd, passes `currentSystem*` args.

- machines/macbook-pro-m1.nix (nix-darwin)
  - stateVersion = 6; leaves Nix daemon to Determinate installer (`nix.enable = false`).
  - Optional Linux builder (currently disabled); zsh program enable; basic tools (e.g., cachix).
  - Imports core modules for shared nix settings.

- machines/main-pc.nix (NixOS Desktop)
  - Imports `hardware/main-pc.nix` for hardware configuration.
  - AMD Ryzen setup with zen kernel, power management, and firmware updates.
  - Docker and libvirtd for virtualization.
  - System packages and optional GUI applications.

- machines/wsl.nix (NixOS-WSL)
  - Enables WSL module, sets default user; stateVersion 24.05.
  - Imports shared nix-settings module.

- modules/core/nix-settings.nix
  - Shared Nix configuration: experimental-features (flakes, nix-command), keep-outputs, keep-derivations.
  - Imported by all machines for consistency.

- modules/core/security.nix
  - Security defaults: rtkit (for audio), polkit (privilege prompts), SSH with secure defaults.
  - Centralized security configuration.

- modules/desktop/gnome.nix
  - GDM (Wayland), GNOME desktop, popular extensions, portals; forces GNOME session vars, disables greetd/seatd.

- modules/desktop/hyprland.nix
  - Hyprland from upstream input, xdg-desktop-portal-hyprland, Xwayland, greetd login manager.

- users/maxpw/home-manager.nix
  - Shared HM config for Linux/macOS; imports fonts and package modules.
  - Sets EDITOR/PAGER/MANPAGER; links macOS Rectangle config and Linux Ghostty config.
  - Configures git (signing key, aliases), shells (bash/zsh/fish/nushell), neovim; Linux gpg-agent.

- users/maxpw/packages/*.nix
  - dev-tools.nix: Programming languages, LSPs, build tools, cloud/infrastructure tools.
  - terminal-tools.nix: CLI utilities, git tools, shell prompts, AI tools.
  - linux-desktop.nix: Wayland tools, GUI applications, desktop utilities (Linux only).

- users/maxpw/nixos.nix (NixOS user/system)
  - Imports core modules (nix-settings, security) and Hyprland desktop module.
  - Sets timezone/locale; US Colemak xkb; PipeWire; user `maxpw` in useful groups; Firefox; stateVersion 24.05.

- users/maxpw/darwin.nix (nix-darwin user/system)
  - Homebrew brews & casks (1Password, Rectangle, browsers, IDEs, VPN, Docker Desktop, etc.).
  - Declares `users.users.max-vev` and `system.primaryUser`.

- users/maxpw/fonts.nix (Home Manager)
  - Installs Nerd Fonts and common font families; enables fontconfig and defaults.

- scripts/nixos-rebuild.sh
  - Autodetects Darwin vs NixOS and host from user; validates flake, formats with alejandra, shows diffs, builds/applies, commits, runs GC.
  - Uses `darwin-rebuild` on macOS and `nixos-rebuild` on NixOS.

## Using this flake

### For new systems

See [BOOTSTRAP.md](BOOTSTRAP.md) for detailed instructions on setting up a new system.

Quick start:
```bash
git clone <your-repo-url> ~/nix-config
cd ~/nix-config
./scripts/bootstrap.sh
```

Or with Make:
```bash
make bootstrap
```

### For existing systems

Suggested clone path: `~/nix-config` (the rebuild script assumes this).

- macOS (Apple Silicon)
  - Apply: `sudo darwin-rebuild switch --flake .#macbook-pro-m1`
  - Or run: `./scripts/nixos-rebuild.sh`
  - Or use: `make rebuild`

- NixOS Desktop
  - Apply: `sudo nixos-rebuild switch --flake .#main-pc`
  - Or run: `./scripts/nixos-rebuild.sh`
  - Or use: `make rebuild`

Optional checks

```bash
make check            # validate flake
make update           # update inputs
make dev              # enter dev shell
make help             # show all make targets
```

## Notes

- INTEGRATION_SUMMARY.md describes an older hosts/modules layout; the canonical structure is this README.
- Hyprland comes from the upstream flake input to ensure recent builds on aarch64.
- On macOS, Nix is managed by the Determinate installer; nix-darwin’s `nix.enable` is disabled accordingly.

## License

Personal configuration; reuse at your own risk.
