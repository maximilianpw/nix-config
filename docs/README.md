# Documentation index

This index lists the maintained documentation. Git history is the archive for
completed plans and superseded research.

## Start here and ownership

- [Repository overview](../README.md)
- [Bootstrap](../BOOTSTRAP.md)
- [Configuration ownership and recovery](config-ownership-and-recovery.md)
- [Fleet and remote development](../modules/fleet/README.md)

## Recovery and storage

- [Homelab recovery](homelab-recovery.md)
- [Storage attachment and replacement](homelab-storage.md)
- [Restore drill records](restore-drills/README.md)
- [Kim headless operations checklist](beelink-headless-checklist.md)

## Service runbooks

- [Atuin](atuin.md)
- [Immich](immich.md)
- [Leerr](leerr.md)
- [Media stack](media-stack.md)
- [Nextcloud Calendar](nextcloud-calendar.md)
- [Paperless](paperless.md)
- [CLIProxyAPI gateway](../modules/cliproxyapi/README.md)

## Platform setup

- [Cuno NixOS-WSL setup](wsl-setup.md)

## Accepted decisions

- [Media stack decision record](media-stack-research.md)

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

Open follow-up: generate `scripts/ynab-mcp-operations.json` reproducibly once
its upstream OpenAPI provenance is decided.
