# Plan 006: Split the media stack into focused NixOS modules without changing behavior

> **Executor instructions**: This is a pure structural refactor. Preserve the evaluated configuration exactly. Add files first, switch the aggregator, and run the media regression after each extraction. Do not activate Kim. Update `advisor-plans/README.md` when complete.
>
> **Drift check (run first)**: `git diff --stat 31341e0 -- homelab/media.nix homelab/default.nix tests/media-stack-regression.nix lib/homelab-services.nix docs/media-stack.md`
> If dependency plans intentionally changed an in-scope path, reconcile this plan against the new code before proceeding. For any other staged, unstaged, or committed drift, STOP and report instead of applying stale excerpts.

## Status

- **Status**: DONE
- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: Plan 001, so package ownership is stable before moving module code
- **Category**: tech-debt
- **Planned at**: commit `31341e0`, 2026-09-16

## Why this matters

`homelab/media.nix` is a 689-line module containing four distinct deployment boundaries: shared media identities/storage, host-native media services, Tunarr, and two VPN-isolated downloader containers with host proxies. The current file makes every change appear to affect the whole stack and hides which helpers are shared. Splitting along these real boundaries improves reviewability while preserving the intentionally coupled media stack and its single top-level import.

## Current state

`homelab/media.nix` currently contains:

- lines 1-234: endpoints, IDs/addresses, VPN/container/proxy helpers, Tunarr and Prowlarr reconciliation, media directory definitions;
- lines 235-343: users/groups, native Bazarr/Jellyfin/Lidarr/Sonarr/Radarr/Prowlarr/Seerr services, shared directories, service overrides, host firewall and NAT;
- lines 344-425: Tunarr user and systemd service details are interleaved with host setup;
- lines 426-577: the qBittorrent/Mullvad container plus Tinyproxy and FlareSolverr;
- lines 578-689: the SABnzbd/Mullvad container.

The file already has useful local helpers:

```nix
mkDeferredVpnService = { serviceName, description, environment ? {}, extraServiceConfig ? {}, vpnGate, }: { ... };
mkVpnContainer = { hostAddress, localAddress, bindMounts, port, applicationModule, }: { ... };
mkContainerProxyService = _: proxy: { ... };
mkContainerProxySocket = _: proxy: { ... };
```

The repository convention is one functional area per file under `homelab/`, composed by `homelab/default.nix`. Preserve `homelab/media.nix` as the public aggregator so no machine/import path changes.

## Target structure

Create this structure:

```text
homelab/media/
  common.nix          # pure function returning constants and helper constructors only
  host-services.nix   # users/groups, media directories, native services, proxies, firewall, NAT
  tunarr.nix          # Tunarr user/service/reconciliation and sandbox
  qbittorrent.nix     # qbt container, Tinyproxy, FlareSolverr, VPN gates
  sabnzbd.nix         # sab container and VPN gate
```

`common.nix` must not return a NixOS module and must not declare users, services, NAT, firewall, or other config. `homelab/media.nix` remains the stable aggregator and imports the four NixOS modules. Pass shared values by importing `common.nix` from each focused module with explicit `{ config, lib, pkgs }` inputs; do not use `_module.args` or create new public options.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `alejandra --check homelab/media.nix homelab/media/*.nix tests/media-stack-regression.nix` | exit 0 |
| Nix lint | `make lint` | exit 0 |
| Media regression | `nix build .#checks.x86_64-linux.media-stack-regression --no-link` | exit 0 after every extraction |
| Eval | `nix flake check --no-build` | exit 0 |
| Host build | `nix build .#nixosConfigurations.kim.config.system.build.toplevel --no-link` | exit 0 |
| Diff hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- `homelab/media.nix`
- New files under `homelab/media/`
- `tests/media-stack-regression.nix` only for path-independent structural test cleanup; behavior assertions must not be weakened
- `homelab/default.nix` only if required, though the preferred design keeps its existing `./media.nix` import

**Out of scope**:
- Service additions/removals or version upgrades
- Endpoint, UID/GID, IP address, port, path, firewall, NAT, VPN, timer, or sandbox changes
- State migration
- Documentation rewrite
- Changes to `lib/homelab-services.nix`
- Activation or live container operations

## Git workflow

- Suggested branch: `advisor/006-split-media-module`
- Commit after each safe extraction or as one focused refactor. Suggested final message: `refactor: split media stack modules`.

## Steps

### Step 1: Capture the evaluated baseline

Before editing, record derivation baselines and build the regression:

```bash
nix eval --raw .#checks.x86_64-linux.media-stack-regression.drvPath > /tmp/media-check-before
nix eval --raw .#nixosConfigurations.kim.config.system.build.toplevel.drvPath > /tmp/kim-before
nix build .#checks.x86_64-linux.media-stack-regression --no-link
```

These paths are machine-checkable fingerprints of the evaluated configuration used by the check and host build. Do not commit the temporary files.

**Verify**: both baseline files are non-empty and the regression exits 0.

### Step 2: Extract shared definitions

Move constants and pure helper constructors into `homelab/media/common.nix`. Keep all literal values unchanged. The file returns values only; it declares no NixOS configuration.

Common definitions include only values genuinely used across modules: media paths/IDs, container addresses, Mullvad gate, generic container constructor, downloader proxy definitions, and shared directory metadata.

**Verify**: media regression exits 0.

### Step 3: Extract host-native services and shared host wiring

Move Bazarr, Jellyfin, Lidarr, Sonarr, Radarr, Prowlarr, Seerr, the shared `media` group, qBittorrent/SAB host-side reserved users, Jellyfin groups, tmpfiles, host proxy sockets/services, host firewall, graphics enablement, and NAT into `host-services.nix`.

Keep the Tunarr user in `tunarr.nix`. Keep qBittorrent/SAB application configuration in their container modules; only host-side identities, proxies, and NAT belong here.

**Verify**: media regression exits 0 and evaluated service/container names are unchanged.

### Step 4: Extract Tunarr

Move Tunarr's user/group membership, reconciliation script, environment, service unit, media visibility restrictions, state directory, and sandbox to `tunarr.nix`. Preserve exact `ExecStart`, `ExecStartPre`, paths, groups, UMask, address families, and endpoint values.

**Verify**: media regression exits 0, particularly all Tunarr assertions.

### Step 5: Extract each downloader container

Move qBittorrent plus Tinyproxy/FlareSolverr into `qbittorrent.nix`. Move SABnzbd into `sabnzbd.nix`. Both may consume shared constructors and constants, but each file should own its application-specific config, bind mounts, users, VPN pre-start wrapper, and deferred service definitions.

Do not generalize qBittorrent and SAB settings into a large abstract schema; share only the existing proven common mechanics.

**Verify** after each extraction: media regression exits 0.

### Step 6: Reduce the aggregator

Make `homelab/media.nix` import the focused modules. Keep it as the stable import path and place a short comment describing the module boundaries.

**Verify**: `nix flake check --no-build` exits 0.

### Step 7: Build Kim

Run formatting, `make lint`, media regression, evaluation, and the Kim closure build. Then compare derivation fingerprints:

```bash
nix eval --raw .#checks.x86_64-linux.media-stack-regression.drvPath > /tmp/media-check-after
nix eval --raw .#nixosConfigurations.kim.config.system.build.toplevel.drvPath > /tmp/kim-after
diff -u /tmp/media-check-before /tmp/media-check-after
diff -u /tmp/kim-before /tmp/kim-after
```

**Verify**: all commands exit 0 and both diffs are empty. If source refactoring alone changes a derivation path, STOP and report the exact derivation difference rather than accepting a subjective review.

## Test plan

No new behavior is intended. `tests/media-stack-regression.nix` is the characterization test and must continue protecting:

- loopback/firewall exposure;
- UIDs/GIDs and shared media permissions;
- Tunarr sandbox and media visibility;
- downloader container network isolation and Mullvad gates;
- proxy sockets and endpoints;
- `/srv` dependencies;
- backup inclusion/exclusion and quiesce units.

Add an import/evaluation assertion only if splitting reveals an untested boundary; do not rewrite the test around file names.

## Done criteria

- [ ] `homelab/media.nix` is a small stable aggregator.
- [ ] Host services, Tunarr, qBittorrent, and SABnzbd have focused owning modules.
- [ ] Shared helpers are pure and limited to genuine common behavior.
- [ ] No literal endpoint, ID, path, unit, firewall, NAT, VPN, or sandbox value changed.
- [ ] Media regression passes after every extraction and at completion.
- [ ] `make lint`, `nix flake check --no-build`, and Kim build pass.
- [ ] Before/after media-check and Kim toplevel derivation paths are identical.
- [ ] No state migration or activation occurs.

## STOP conditions

- Preserving behavior requires changing module option merge precedence.
- The extraction changes generated unit names, container addresses, users/groups, paths, or firewall/NAT rules.
- A helper abstraction would need application-specific conditionals for both downloaders; keep those details local instead.
- Existing media regression fails before edits.
- The refactor appears to require changing documentation because behavior changed.

## Maintenance notes

Keep the stack coupled at the aggregator and inventory levels; this plan improves implementation boundaries, not product architecture. Reviewers should compare evaluated behavior, not merely file movement.

## Completion notes

Completed on 2026-09-16 after restoring exact generated-unit ordering.

- The split initially reordered the order-insensitive `After=` dependencies in
  `tunarr.service`. `lib.mkBefore` now keeps the original rendered value,
  `After=network-online.target srv.mount`.
- The media regression derivation is unchanged at
  `/nix/store/5lx0rdxsxqnjicnkf0hbsppdc6gwma93-media-stack-regression.drv`.
- The Kim toplevel derivation is unchanged at
  `/nix/store/xrp7pnkn7ffi5f81f21mh3r8nsj09kgc-nixos-system-kim-26.05.20260911.21a67dc.drv`
  when compared before and after with the same evaluator.
- Formatting, lint, no-build flake evaluation, diff hygiene, the media
  regression build, and the Kim toplevel build passed. The two Linux builds ran
  on Kim from a disposable source snapshot without activation.
- A follow-up removed the duplicate Tunarr user/group declaration from
  `host-services.nix`; `tunarr.nix` is now the sole owner. Both fingerprints
  remained identical and the media regression and Kim toplevel builds passed.
