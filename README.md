# Nix configuration

This flake manages three hosts for Maximilian:

- `kim`, an x86_64 NixOS homelab;
- `cuno`, an x86_64 NixOS-WSL environment;
- `joyce`, an Apple Silicon nix-darwin workstation.

It also keeps a parked, evaluable Hyprland profile for Kim. Its desktop
configuration and assets are intentionally retained for a future desktop host,
even when currently unused. Revachol is the remote-development fleet name,
while its command remains `fleet`.

## Ownership map

- `lib/hosts.nix` is the host and Fleet inventory.
  `lib/inventory.nix` validates and normalizes it, and `lib/mksystem.nix`
  constructs system outputs.
- `lib/homelab-services.nix` owns service exposure, state, backup, monitoring,
  storage, and recovery metadata. Application implementation stays in the
  owning module under `homelab/`.
- `machines/` contains host-specific operating-system configuration.
- `modules/` contains shared system, Fleet, desktop, and CLIProxyAPI modules.
- `users/maxpw/` contains Home Manager and platform-specific user
  configuration.
- `scripts/` holds operational scripts grouped by purpose (`rebuild/`,
  `homelab/`, `dev/`, `user/`, `ci/`); `scripts/tests/` is what
  `make check-scripts` runs. `tests/` holds the flake checks and their fixtures.
- `packages/` contains repository-owned package definitions. Flake package and
  check registration live in `flake.nix` and `lib/checks.nix`.

Nix and Home Manager own systems, packages, shells, and executables. Nixvim
owns Neovim and Hjem owns static application files. The external
`pi-config` repository owns Pi settings, prompts, extensions, and themes. The
pinned Fleet input owns the installed runtime CLI and tunnel supervision.
This repository owns the personal Fleet inventory, SSH policy, trust, aliases,
generated contract, and consumer compatibility checks. It does not retain a
second CLI implementation. Do not give two systems the same destination.

See the [documentation index](docs/README.md) for runbooks, recovery guidance,
accepted decisions, and open work.

## Common workflow

Bootstrap a new machine with [BOOTSTRAP.md](BOOTSTRAP.md). For an existing
checkout, choose checks that match the change as listed in
[AGENTS.md](AGENTS.md#local-workflow-and-checks).

`make update-all` refreshes every repository-managed runtime pin: flake inputs
(including explicit release tags and commits), custom packages and their platform
hashes, T3 Code nightlies, Neovim and Fish plugins, and homelab container digests.
Plannotator's Claude/OpenCode plugin pins are synchronized with the locked CLI.
It needs the tools in `nix develop` and authenticated `gh` access to private
inputs; the container target obtains Skopeo from the locked nixpkgs input.
Linux binary packages are refreshed from macOS too, without running them.

The command attempts every update group and exits nonzero if any fails.
Successful edits remain in the worktree; inspect the diff and retry the named
failed targets. `PACKAGES` can narrow `make update-packages`, but is deliberately
ignored by `make update-all`. Obsidian, Herdr Core and Plex refresh all of their
platform hashes together; failures leave that package's source file unchanged.

Release-pinned inputs follow the newest stable tag at or above the current pin
whose Nix-fetched source contains `flake.nix`. Tags missing that file are reported
and skipped; fetch/authentication failures remain errors. Commit-pinned inputs
follow the upstream default branch, also checked for `flake.nix` before writing.
Container updates preserve digest pinning:
Executor follows the v2 release/beta line (not its v1 `latest` tag), while the
media containers follow `latest`. Review compatibility before applying updates,
especially for database-backed services. NixOS release branches, explicit major
package selections (such as Nextcloud), and state-version compatibility settings
are not automatically migrated. CI action pins are not runtime dependencies.

This only refreshes source definitions and lockfiles. It does not deploy, restart
containers, upgrade Homebrew or mutable Nextcloud apps, or modify dependencies
in other checkouts such as `pi-config`. Build and run the relevant checks before
explicitly choosing `make rebuild`. `make update` remains the narrower core-input,
T3 Code and Neovim update (also synchronizing Plannotator plugins).

`make help` lists the other supported targets.

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
