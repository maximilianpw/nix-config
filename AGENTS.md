# Nix configuration guidance

## Purpose and ownership

This flake defines NixOS hosts `kim` and `cuno`, nix-darwin host `joyce`, their
Home Manager configuration, and Kim's homelab services.

- `lib/hosts.nix` is the host/fleet inventory. `lib/inventory.nix` validates and
  normalizes it; `flake.nix` and `lib/mksystem.nix` build system outputs from it.
- Host concerns belong in `machines/`; shared system concerns in `modules/`;
  user and platform concerns in `users/maxpw/`. Keep substantial OS divergence
  in `nixos.nix`, `darwin.nix`, or `wsl.nix`.
- `lib/homelab-services.nix` owns service metadata and recovery contracts;
  application options and implementation stay in their owning `homelab/`
  module. See `README.md` and `docs/homelab-recovery.md`.
- Nix/Home Manager owns systems, packages, shells, and executables. The separate
  chezmoi repository owns Neovim and app content; `pi-config` owns Pi resources.
  Do not give two systems the same destination. See
  `docs/config-ownership-and-recovery.md`.

## Local workflow and checks

Local edits, formatting, evaluation, builds, and tests are safe without asking.
Use `nix develop` when the required repository tools are not already available.
Run checks proportional to the change and persist through inspect/fix/re-run:

- Documentation or guidance only: `git diff --check`.
- Changed Nix files: `alejandra --check <files>` and `make lint`.
- Module, inventory, or flake behavior: `nix flake check --no-build`.
- Shell scripts: `make check-scripts`.
- One regression: discover its check in `flake.nix`, then run
  `nix build .#checks.x86_64-linux.<name> --no-link`.
- Broad or release-level work: `nix flake check` (full build checks).

`make build` builds the detected host without switching it. Do not use the full
suite for a trivial documentation edit. Completion means the diff was inspected,
the narrowest meaningful checks pass, and affected documentation still matches
the behavior; report any check that could not run.

## Safety boundaries and traps

- Never run rebuild, bootstrap, rollback, WSL-image, restore, migration, cleanup,
  or deployment commands unless explicitly requested. Building/evaluating is
  not permission to switch a host or contact a service.
- Keep secrets encrypted with sops. Never print decrypted values or place keys,
  credentials, mutable service data, or restore artifacts in Git/Nix store.
- Do not edit generated `.pre-commit-config.yaml` or generated hardware config.
- Never change `system.stateVersion` or `home.stateVersion` as a package upgrade.
- Joyce's Nix daemon is owned by Determinate: keep `nix.enable = false`; daemon
  settings live in `/etc/nix/nix.custom.conf` via `machines/joyce.nix`.
- macOS GUI apps belong in Homebrew declarations; activation cleanup is `zap`.
- Hyprland comes from the flake input, not nixpkgs.
- Storage/recovery work requires the dedicated runbooks. Never point restore or
  provisioning tools at live paths or unconfirmed disks.
