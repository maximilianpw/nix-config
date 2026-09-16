# Nix configuration

This flake manages three hosts for Maximilian:

- `kim`, an x86_64 NixOS homelab;
- `cuno`, an x86_64 NixOS-WSL environment;
- `joyce`, an Apple Silicon nix-darwin workstation.

It also keeps a parked, evaluable Hyprland profile for Kim. Revachol is the
remote-development fleet name, while its command remains `fleet`.

## Ownership map

- `lib/hosts.nix` is the host and Fleet inventory.
  `lib/inventory.nix` validates and normalizes it, and `lib/mksystem.nix`
  constructs system outputs.
- `lib/homelab-services.nix` owns service exposure, state, backup, monitoring,
  storage, and recovery metadata. Application implementation stays in the
  owning module under `homelab/`.
- `machines/` contains host-specific operating-system configuration.
- `modules/` contains shared system, Fleet, desktop, and service modules.
- `users/maxpw/` contains Home Manager and platform-specific user
  configuration.
- `packages/` contains repository-owned package definitions. Flake package and
  check registration live in `flake.nix` and `lib/checks.nix`.

Nix and Home Manager own systems, packages, shells, and executables. The
separate chezmoi repository owns Neovim and application content. The external
`pi-config` repository owns Pi settings, prompts, extensions, and themes. The
pinned Fleet input owns the installed runtime CLI and tunnel supervision.
This repository owns the personal Fleet inventory, SSH policy, trust, aliases,
generated contract, and consumer compatibility checks. It does not retain a
second CLI implementation. Do not give two systems the same destination.

See the [documentation index](docs/README.md) for runbooks, recovery guidance,
accepted decisions, and open work.

## Common workflow

Bootstrap a new machine with [BOOTSTRAP.md](BOOTSTRAP.md). For an existing
checkout, choose checks that match the change:

```sh
# Documentation or guidance
git diff --check

# Changed Nix files
alejandra --check <files>
make lint

# Module, inventory, or flake behavior
nix flake check --no-build

# Shell scripts
make check-scripts

# One x86_64-linux regression
nix build .#checks.x86_64-linux.<name> --no-link

# Build the detected host without switching it
make build
```

`make help` lists the other supported targets. `make chezmoi-bootstrap` clones
the dotfiles source without applying it. Review changes with
`make chezmoi-preview` before an interactive `make chezmoi-apply`.

## Safety boundaries

- Builds and evaluation do not activate a configuration. Rebuild, deployment,
  restore, migration, disk, and cleanup commands require an explicit operator
  decision.
- Secrets stay encrypted with SOPS. Never put private keys, decrypted values,
  mutable service data, or restore artifacts in Git or the Nix store.
- Determinate owns Joyce's Nix daemon. Keep `nix.enable = false`; daemon
  settings belong in `/etc/nix/nix.custom.conf` through `machines/joyce.nix`.
- `system.stateVersion` and `home.stateVersion` are compatibility settings, not
  package upgrade controls.
- Hyprland comes from the flake input. macOS GUI applications belong in the
  Homebrew declarations.
- Before storage or recovery work, read
  [the recovery runbook](docs/homelab-recovery.md) and the affected service
  runbook. Never point restore or provisioning tools at live paths or an
  unconfirmed disk.

## License

Personal configuration; reuse at your own risk.
