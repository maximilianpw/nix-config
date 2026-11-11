# Nix configuration

This flake manages three hosts:

- `kim`, an x86_64 NixOS homelab;
- `cuno`, an x86_64 NixOS-WSL environment;
- `joyce`, an Apple Silicon nix-darwin workstation.

A parked Hyprland profile for a future desktop host still evaluates as
`desktopKim`.

## Layout

- `lib/hosts.nix`: host and Fleet inventory; `lib/mksystem.nix` builds hosts from it.
- `lib/homelab-services.nix`: homelab service metadata (exposure, state, backup,
  monitoring, recovery). Implementations live in `homelab/`.
- `machines/`: per-host OS configuration. `modules/`: shared system modules.
- `users/maxpw/`: Home Manager, Nixvim (`neovim/`) and Hjem (`hjem/`) config.
- `packages/`: repository-owned packages. `scripts/`: operational scripts.
  `tests/`: flake regression checks.

## Workflow

- New machine: [BOOTSTRAP.md](BOOTSTRAP.md). Secrets: [secrets/README.md](secrets/README.md).
- Homelab restore: [docs/homelab-recovery.md](docs/homelab-recovery.md).
- `make help` lists targets. `make update-all` refreshes every pin without
  deploying; review the diff and build before `make rebuild`.
- Which checks to run for a change: [AGENTS.md](AGENTS.md#local-workflow-and-checks).
