# Plan 007: Let service modules contribute backup version metadata

> **Executor instructions**: Preserve manifest schema version 1 and every existing application-version key. Introduce the typed contribution option first, migrate owners incrementally, and keep central completeness validation. Stop if service ownership is ambiguous. Update `advisor-plans/README.md` when complete.
>
> **Drift check (run first)**: `git diff --stat 31341e0 -- modules/services/backup.nix homelab/default.nix homelab/*.nix tests/homelab-backup-regression.nix tests/homelab-inventory-regression.nix lib/homelab-services.nix`
> If dependency plans intentionally changed an in-scope path, reconcile this plan against the new code before proceeding. For any other staged, unstaged, or committed drift, STOP and report instead of applying stale excerpts.

## Status

- **Status**: DONE
- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: Plan 006, because media service ownership should be clear before moving qBittorrent/SAB/Tunarr/Jellyfin version contributions
- **Category**: tech-debt
- **Planned at**: commit `31341e0`, 2026-09-16

## Why this matters

`modules/services/backup.nix` currently knows how to find the package version or image identifier for every stateful application, including packages hidden inside containers and user-specific settings. Adding or replacing a service therefore requires editing an unrelated 510-line coordinator. Service modules should contribute their own non-secret version identifiers while the backup module remains responsible for schema assembly and completeness validation.

## Current state

`modules/services/backup.nix:51-80` contains a manual map:

```nix
applicationVersions = {
  actual = config.services.actual.package.version;
  atuin = config.services.atuin.package.version;
  ...
  qbittorrent = config.containers.qbt.config.services.qbittorrent.package.version;
  sabnzbd = config.containers.sab.config.services.sabnzbd.package.version;
  t3code = t3codeVersion;
  tunarr = pkgs.tunarr.version;
  vaultwarden = config.services.vaultwarden.package.version;
  uptimeKuma = config.services.uptime-kuma.package.version;
};
```

It then derives stateful service names from `lib/homelab-services.nix` and asserts that every one has a key. Preserve that assertion.

Special cases:

- `executor` records an OCI image identifier rather than a package version.
- `t3code` reads `users/<user>/settings.nix`. Its owner is a Home Manager module in a separate module system, so this plan deliberately keeps `t3code` as the one documented central exception in `backup.nix`; do not invent a NixOS/Home Manager bridge for one string.
- qBittorrent and SABnzbd live inside containers.
- `uptimeKuma` is a schema-v1 compatibility alias while canonical inventory uses `kuma`; preserve both keys if existing archives/restore tooling expect them.
- `manifestMetadata.schemaVersion` must remain `1`.

Repository convention: homelab application configuration belongs in its owning module under `homelab/`; shared backup orchestration remains in `modules/services/backup.nix`.

## Target design

Add an internal typed option, for example:

```nix
options.custom.backup.applicationVersions = lib.mkOption {
  type = lib.types.attrsOf lib.types.str;
  default = {};
  internal = true;
  description = "Non-secret application package/image identifiers recorded in backup manifests.";
};
```

Owning modules contribute with ordinary module merging:

```nix
custom.backup.applicationVersions.actual = config.services.actual.package.version;
```

The backup module consumes `cfg.applicationVersions`, adds only true schema aliases and the documented T3 Code cross-module exception centrally, validates completeness against stateful inventory names, and writes the same manifest shape.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format | `alejandra --check modules/services/backup.nix homelab/*.nix homelab/media/*.nix tests/homelab-backup-regression.nix` | exit 0 |
| Nix lint | `make lint` | exit 0 |
| Inventory check | `nix build .#checks.x86_64-linux.homelab-inventory-regression --no-link` | exit 0 |
| Backup check | `nix build .#checks.x86_64-linux.homelab-backup-regression --no-link` | exit 0 |
| Runtime shell suite | `bash scripts/tests/homelab-backup-coordinator-test.sh && bash scripts/tests/homelab-backup-inspect-test.sh && bash scripts/tests/t3code-backup-test.sh` | all exit 0 |
| Evaluation | `nix flake check --no-build` | exit 0 |
| Host build | `nix build .#nixosConfigurations.kim.config.system.build.toplevel --no-link` | exit 0 |

## Scope

**In scope**:
- `modules/services/backup.nix`
- Owning `homelab/*.nix` service modules
- Media submodules created by Plan 006
- `tests/homelab-backup-regression.nix`
- `tests/homelab-inventory-regression.nix` only if a typed-option validation case is added

**Out of scope**:
- Manifest schema version change
- Renaming existing manifest keys
- Backup paths, excludes, quiesce order, restore order, or archive behavior
- Database versions or PostgreSQL metadata changes
- Live backup, restore, mount, or host activation
- Moving recovery metadata out of `lib/homelab-services.nix`

## Git workflow

- Suggested branch: `advisor/007-backup-version-ownership`
- Suggested commit: `refactor: let services declare backup versions`

## Steps

### Step 1: Characterize the existing manifest map

Use Nix evaluation or the existing backup regression to capture the exact attribute names and values/types of `config.custom.backup.manifestMetadata.applicationVersions`. Store any comparison output outside Git.

**Verify**: the existing backup regression exits 0 and the complete key set is recorded.

### Step 2: Add the internal contribution option

Add `custom.backup.applicationVersions` under the existing `options.custom.backup` block. Use `attrsOf str`, default `{}`, and `internal = true`. Do not expose a user-facing service toggle.

Temporarily make the central manual map merge with the option so migration can be incremental, but add an assertion preventing conflicting duplicate values if both define the same key.

**Verify**: `nix flake check --no-build` exits 0 before moving contributions.

### Step 3: Move ordinary service contributions

For each owning module, add its version contribution near the service declaration. Migrate simple native services first: Actual, Atuin, Grafana, Home Assistant, Homepage, Immich, Jellyfin, Kuma, Leerr, Servarr services, Miniflux, Nextcloud, Paperless, Prometheus, Seerr, Syncthing, Tunarr, and Vaultwarden.

Use the already-configured package rather than calling package files again. For example, Leerr should reference the service/package value exposed by its owning module if available; do not duplicate `pkgs.callPackage` merely to read `.version`.

**Verify** after batches: backup regression exits 0.

### Step 4: Move special contributions

Handle explicitly:

- `executor`: owning module contributes the image string;
- qBittorrent and SABnzbd: media container modules contribute evaluated container package versions;
- `t3code`: keep the existing `users/${currentSystemUserDir}/settings.nix` lookup centrally, add a comment explaining that Home Manager is a separate module system, and exclude this key from the “no service-specific lookup” goal;
- `uptimeKuma`: keep the compatibility alias in central manifest assembly if it is not an actual inventory service name.

If any other owner cannot access its evaluated version without a layering violation, STOP for that service rather than introducing a new reverse dependency.

**Verify**: exact manifest key set and values match the baseline.

### Step 5: Remove the manual service map

Once all NixOS-owned canonical stateful services contribute, remove their service-specific package/image lookups from the backup coordinator. Keep:

- the documented T3 Code Home Manager exception (`t3codeVersion` import);
- completeness validation against stateful inventory names;
- schema-v1 aliases;
- manifest assembly and PostgreSQL/system metadata.

Add an assertion/test that an enabled stateful service missing a version contribution fails evaluation with the existing clear error.

**Verify**: inventory and backup regressions both pass.

### Step 6: Run runtime and build verification

Run all listed shell tests, evaluation, formatting, and Kim closure build.

**Verify**: all exit 0; do not run a live Borg job.

## Test plan

- Preserve the existing backup regression's manifest assertions.
- Add a fixture/evaluation case proving a missing stateful-service contribution fails.
- Add a case for duplicate conflicting contributions if the module system would otherwise silently choose one.
- Keep runtime coordinator/inspect/T3 Code backup tests unchanged; they protect separate behavior layers.

## Done criteria

- [ ] Every stateful service owner contributes its version/image identifier.
- [ ] Backup coordinator contains no NixOS-service-specific package lookup; only deliberate schema aliases, system metadata, and the documented T3 Code Home Manager exception remain.
- [ ] Manifest schema remains version 1.
- [ ] Existing application-version keys and values match the baseline.
- [ ] Completeness validation remains central and tested.
- [ ] `make lint`, backup/inventory regressions, runtime shell tests, evaluation, and Kim build pass.
- [ ] No live backup or restore operation occurs.

## STOP conditions

- A service module cannot access its version without importing backup internals or another owner's implementation.
- Existing archive consumers require undocumented keys that cannot be traced.
- The refactor changes a manifest value from a package version to a different identifier.
- Module merging creates ambiguous conflicting contributions.
- Any runtime backup behavior changes.

## Maintenance notes

Future stateful services should add inventory recovery metadata and their backup-version contribution in the same owning module change. The central coordinator should only validate and serialize the complete view.

## Completion notes

Completed on 2026-09-16.

- The complete 27-key application-version map matched before and after,
  including the `uptimeKuma` schema-v1 alias and the pinned Executor image.
- NixOS service modules now contribute canonical version identifiers through
  the internal `custom.backup.applicationVersions` option. The backup module
  retains only the T3 Code Home Manager lookup and the compatibility alias.
- The backup regression covers the contribution key set, a missing stateful
  service contribution, and conflicting duplicate values.
- Formatting, lint, no-build flake evaluation, diff hygiene, both Linux
  regressions, all three runtime shell tests, and the Kim toplevel build passed.
  Linux checks ran on Kim from a disposable source snapshot without activation
  or live backup operations.
