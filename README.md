# Nix-Config

Unified NixOS + macOS (nix-darwin) flake for a headless homelab, Apple Silicon
workstation, WSL environment, and a parked/tested Hyprland desktop profile.

## Repository layout

```
.
├── AGENTS.md               # Agent instructions for this repository
├── BOOTSTRAP.md            # New-system bootstrap guide
├── CLAUDE.md               # Claude Code repository guidance
├── Makefile                # Convenience commands for build/rebuild/update
├── flake.nix                # Main flake: inputs, overlays, and outputs
├── flake.lock
├── docs/                    # Supplemental documentation
│   ├── hardware-issues.md
│   └── wsl-setup.md
├── homelab/                 # self-hosted services; public Cloudflare + private Tailscale Serve
├── lib/
│   ├── hosts.nix            # Canonical typed host/profile/fleet inventory
│   └── mksystem.nix         # mkSystem builder (NixOS & Darwin + Home Manager)
├── machines/
│   ├── macbook-pro-m1.nix   # macOS (nix-darwin) host
│   ├── main-pc.nix          # Headless NixOS homelab (Ryzen)
│   ├── wsl.nix              # NixOS-WSL base
│   └── hardware/
│       ├── main-pc-disko.nix # Disko layout for main-pc
│       └── main-pc.nix      # Hardware profile for main-pc
├── modules/
│   ├── core/
│   │   ├── nix-settings.nix # Shared Nix settings (experimental-features, flakes)
│   │   ├── security.nix     # Security defaults (SSH, polkit, rtkit)
│   │   ├── shells.nix       # System-level shell registration
│   │   └── sops.nix         # sops-nix integration
│   ├── desktop/
│   │   └── hyprland.nix     # Hyprland from upstream flake (+portals, env)
│   ├── fleet/
│   │   ├── README.md        # Remote dev fleet usage and adding-machine notes
│   │   ├── home-manager.nix # Fleet inventory, SSH matchblocks, and fleet CLI
│   │   └── nixos.nix        # Tailscale, mosh, and tmux for fleet nodes
│   └── services/
│       └── backup.nix       # Borg backup service
├── packages/
│   ├── coderabbit.nix       # Custom package: CodeRabbit CLI
│   ├── helium.nix           # Custom package: Helium floating browser
│   └── obsidian.nix         # Custom package: Obsidian
├── scripts/
│   └── nixos-rebuild.sh     # Smart rebuild script (Darwin/NixOS autodetect)
├── secrets/                 # sops-nix encrypted secrets
│   ├── README.md
│   └── secrets.yaml
├── templates/               # Nix flake templates
│   ├── generic/
│   ├── node/
│   └── rust/
├── users/
│   └── maxpw/
│       ├── home-manager.nix # Main Home Manager config (Linux & macOS)
│       ├── nixos.nix        # NixOS user/system module
│       ├── darwin.nix       # nix-darwin user/system module for macbook-pro-m1
│       ├── wsl.nix          # NixOS-WSL user/system module
│       ├── modules/
│       │   ├── fonts.nix          # Fonts (Nerd Fonts + defaults, fontconfig)
│       │   ├── neovim.nix         # Neovim configuration with LSPs
│       │   ├── vcs/jujutsu.nix    # Jujutsu config
│       │   └── packages/
│       │       ├── custom-scripts.nix # Personal scripts
│       │       ├── dev-tools.nix      # Development packages (languages, tools)
│       │       ├── terminal-tools.nix # CLI utilities and terminal tools
│       │       └── linux-desktop.nix  # Linux GUI apps and Wayland tools
│       ├── config.fish      # fish init (ssh-agent, Homebrew, starship)
│       ├── config.nu        # nushell init (env, direnv hook, helpers)
│       ├── ghostty.linux    # Ghostty config (Linux); linked by HM
│       ├── RectangleConfig.json # Rectangle.app settings (macOS); linked by HM
│       └── [various configs] # Hyprland, waybar, rofi, etc.
├── nixos-switch.log         # Last rebuild log (script output)
└── plans/                   # Reviewed implementation plans
```

## Flake overview

- Inputs: nixpkgs 26.05, nixpkgs-unstable (select pkgs), home-manager 26.05, nix-darwin 26.05, Hyprland, NixOS-WSL, fenix, sops-nix, llm-agents, disko, nix-index-database.
- Overlays: fenix (Rust toolchain); llm-agents (claude-code, codex, opencode, amp-cli, pi, skills, hunkdiff, agent-browser); unstable passthrough (`pkgs.unstable`, plus jujutsu/zig pinned to unstable) and custom packages (helium, obsidian, coderabbit).
- `lib/hosts.nix` is the data-only source for system outputs, profile labels,
  platform metadata, and fleet hosts. Its profile labels are a typed migration
  seam; platform flags still select modules today rather than a new role-module
  framework.
- mkSystem (`lib/mksystem.nix`):
  - Picks nixosSystem or darwinSystem.
  - Adds NixOS-WSL module when `wsl = true`.
  - Integrates Home Manager at `home-manager.users.<user>` using `users/<userDir>/home-manager.nix`.
  - Injects convenience args: `currentSystem*`, `isWSL`, `inputs`.
- Outputs (derived from `lib/hosts.nix`):
  - `nixosConfigurations.main-pc` (x86_64-linux; user: `maxpw`).
  - `darwinConfigurations.macbook-pro-m1` (aarch64-darwin; login `max-vev`, userDir `maxpw`).
  - Eval check for the parked `main-pc` Hyprland profile.
  - `devShells` for aarch64/x86_64 Linux and aarch64 Darwin.

## What each file/module does

- lib/mksystem.nix
  - Chooses NixOS or Darwin system function, wires Home Manager and optional WSL, passes `currentSystem*` args.

- machines/macbook-pro-m1.nix (nix-darwin)
  - stateVersion = 6; leaves Nix daemon to Determinate installer (`nix.enable = false`).
  - Optional Linux builder (currently disabled); zsh program enable; basic tools (e.g., cachix).
  - Imports core modules for shared nix settings.

- machines/main-pc.nix (headless NixOS homelab)
  - Imports `hardware/main-pc.nix` for hardware configuration.
  - AMD Ryzen setup with zen kernel, power management, and firmware updates.
  - Docker and libvirtd for virtualization.
  - System packages and optional GUI applications.

- machines/wsl.nix (NixOS-WSL)
  - Enables WSL module, sets default user; stateVersion 24.05.
  - Imports shared nix-settings module.

- modules/core/nix-settings.nix
  - Shared Nix configuration: experimental-features (flakes, nix-command), store optimization, keep-outputs, keep-derivations.
  - Imported by all machines for consistency.

- modules/core/security.nix
  - Security defaults: rtkit (for audio), polkit (privilege prompts), SSH with secure defaults.
  - Centralized security configuration.

- modules/fleet/
  - Remote-development fleet module: Tailscale/mosh system setup, declarative host inventory, SSH matchblocks, host-key pinning, and the `fleet` helper CLI.

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
  - Uses the actual Linux hostname (WSL is detected explicitly), validates it
    against the inventory, enforces safe SOPS key metadata, then switches with
    `nh` and cleans old generations.
  - Records an identity-checked process tree under the user state directory;
    `make rebuild-processes` and `make cleanup-rebuild` never regex-match
    unrelated Nix jobs.

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

After the first rebuild, initialize dotfiles without applying them, inspect the
diff, then opt into an interactive apply:

```bash
make chezmoi-bootstrap
make chezmoi-preview
make chezmoi-apply
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
nix flake check --no-build
make check-scripts   # shell syntax, ShellCheck, safety regression tests
make update           # update inputs
nix develop           # enter dev shell
make help             # show all make targets
```

## Notes

- Hyprland comes from the upstream flake input to ensure recent builds on aarch64.
- The Hyprland Lua config is installed by Home Manager at the documented default path, `$XDG_CONFIG_HOME/hypr/hyprland.lua` (`~/.config/hypr/hyprland.lua` in practice). The greetd session starts `start-hyprland` without `--config`; live edits can be reloaded with `hyprctl reload`.
- Because Hyprland is launched with UWSM, Wayland toolkit and cursor environment variables are managed in `$XDG_CONFIG_HOME/uwsm/env` instead of the Lua config.
- On macOS, Nix is managed by the Determinate installer; nix-darwin’s `nix.enable` is disabled accordingly.
- Nix/Home Manager owns systems and executables; chezmoi owns Neovim/app
  content. See [configuration ownership and recovery](docs/config-ownership-and-recovery.md).

## License

Personal configuration; reuse at your own risk.
