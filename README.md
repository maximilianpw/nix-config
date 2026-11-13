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
- `machines/`: per-host facts. `profiles/`: one file per host role, listing its
  modules and setting their options.
- `modules/`: every module, with the module system in the path: `home/`,
  `nixos/`, `darwin/` for single files, `<concern>/{home,nixos,darwin,system}.nix`
  for concerns that span systems or own scripts.
- `homelab/`: Kim's services; `homelab/inventory/services.nix` holds their
  exposure, state, backup, monitoring and recovery metadata.
- `users/maxpw/`: the Home Manager base (`home.nix`), Nixvim (`neovim/`) and
  dotfiles. Dotfiles live in `files/managed/` (Hjem store links, rebuild to apply) or
  `files/editable/` (links into this checkout, edits apply live).
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
