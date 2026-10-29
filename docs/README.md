# Documentation index

This index lists the maintained documentation. Git history is the archive for
completed plans and superseded research.

## Start here and ownership

- [Repository overview](../README.md)
- [Bootstrap](../BOOTSTRAP.md)
- [Configuration ownership and recovery](config-ownership-and-recovery.md)
- [Nixvim and Hjem](nixvim-hjem.md)
- [Fleet and remote development](../modules/fleet/README.md)
- [Git merging and dependency-update CI](git-and-ci-workflow.md)
- [Jujutsu, agent workspaces, and stacked PRs](jj-workflow-recommendations.md)

## Recovery and storage

- [Homelab recovery](homelab-recovery.md)
- [Storage attachment and replacement](homelab-storage.md)
- [Restore drill records](restore-drills/README.md)
- [Kim headless operations checklist](beelink-headless-checklist.md)

## Service runbooks

- [Amp self-hosted orbs](amp-orbs.md)
- [Atuin](atuin.md)
- [Forgejo](forgejo.md)
- [Immich](immich.md)
- [Media stack](media-stack.md)
- [Media companions](media-companions.md)
- [Homelab MCP through Executor](media-mcp.md)
- [Nextcloud Calendar](nextcloud-calendar.md)
- [Paperless](paperless.md)
- [Superlocal](superlocal.md)
- [CLIProxyAPI gateway](../modules/cliproxyapi/README.md)

## Platform setup and packaging

- [Cuno NixOS-WSL setup](wsl-setup.md)
- [Rex](rex.md)
- [T3 Code packaging and updates](t3code.md)
- [Vite+ packaging](vite-plus.md)

## Accepted decisions

- [Kim build contention and Nix daemon scheduler weights](kim-build-contention.md)
- [ADR 0001: Unattended agent access on Kim](adr/0001-unattended-agent-access.md)

## Open backlog

- [Homelab backlog](homelab-backlog.md)
- [Agent tooling backlog](agent-tooling-backlog.md)

## Cleanup decisions

Deliberately kept despite looking removable:

- Homelab recovery tests: inventory validation, generated backup wiring,
  runtime failure recovery, archive inspection, and T3 Code snapshot behavior
  are separate safety layers.
- `lib/homelab-services.nix` as one file: it is the typed service and recovery
  inventory.
- Fleet consumer tests: projection, installed-package selection, trust, and
  generated TOML compatibility remain this repository's responsibility.
- Exported `lib.hosts.*.profiles`: external consumers have not been audited.
- Parked Hyprland configuration and assets: retained for a future desktop host.
- CLI packages without repository references (for example Cava): lack of a
  reference does not prove lack of manual use.

Open follow-up: generate `scripts/user/ynab-mcp-operations.json` reproducibly once
its upstream OpenAPI provenance is decided.
