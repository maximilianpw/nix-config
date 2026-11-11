# Nix configuration

This flake manages three hosts:

- `kim`, an x86_64 NixOS homelab;
- `cuno`, an x86_64 NixOS-WSL environment;
- `joyce`, an Apple Silicon nix-darwin workstation.

A parked Hyprland profile for a future desktop host still evaluates as
`desktopKim`.

## Layout

- `lib/`: host inventory (`hosts.nix`) and the plumbing that builds hosts from it.
- `overlays.nix`: package overlays (agent CLIs, unstable picks, pins, `packages/`).
- `machines/`: per-host OS configuration. `modules/`: shared system modules.
- `homelab/`: Kim's services; `homelab/inventory/services.nix` holds their
  exposure, state, backup, monitoring and recovery metadata.
- `users/maxpw/`: Home Manager, Nixvim (`neovim/`) and Hjem (`hjem/`) config.
- `packages/`: repository-built packages and their updaters.
- `scripts/`: repository tooling (`rebuild/`, `ci/`, `dev/`).
- `tests/`: flake checks (`tests/default.nix` registers them).

A script lives beside the Nix file that uses it, and its test beside it as
`<name>-test.sh`; a module that owns scripts is a directory.

## Workflow

- New machine: [BOOTSTRAP.md](BOOTSTRAP.md). Secrets: [secrets/README.md](secrets/README.md).
- Homelab restore: [docs/homelab-recovery.md](docs/homelab-recovery.md).
- `make help` lists targets. `make update-all` refreshes every pin without
  deploying; review the diff and build before `make rebuild`.
- Which checks to run for a change: [AGENTS.md](AGENTS.md#local-workflow-and-checks).
