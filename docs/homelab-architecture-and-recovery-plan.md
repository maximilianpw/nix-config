# Homelab architecture, declarative ownership, and recovery plan

## Outcome

Evolve Kim into a clean, reproducible homelab without losing application data
or pretending that mutable application state is Nix configuration.

The completed setup must provide:

- One typed source of truth for service endpoints, exposure, persistent state,
  backup behavior, storage dependencies, monitoring, and restore ownership.
- Native NixOS service modules with loopback-first networking.
- Application-consistent local backups and an independently recoverable
  off-site copy.
- Tested restoration of every primary stateful application.
- Declarative or explicitly documented ownership of Cloudflare and Tailscale
  control-plane state.
- External alert delivery for host loss, stale backups, storage failure, and
  important service failures.
- A safe path to optional storage encryption or filesystem replacement without
  formatting the only good copy of the data.

This is an incremental plan. Replacing every service, moving all state, or
reformatting storage at once is explicitly not the implementation strategy.

## Status legend

- **Prepared:** implemented in the current worktree but not applied to Kim.
- **Pending:** repository work that can be implemented without provider choice.
- **External decision:** requires a provider, credentials, policy, or user
  preference that cannot be invented safely.
- **Destructive gate:** must not start until independent restore prerequisites
  are proven.

## Non-negotiable invariants

Every phase must preserve these properties:

1. Never format, repartition, replace, or bulk-move `/srv` until two verified
   backup copies exist, with at least one outside Kim's physical failure domain.
2. Never restore directly over live service paths. Extract into a new empty
   staging directory first.
3. Never start a fresh stateful service against an intended restore destination
   before its matching files and database are ready.
4. Restore database and file state from the same backup window.
5. Keep `/srv` consumers fail-closed when the storage filesystem is absent.
6. Keep secrets out of the Nix store and repository plaintext.
7. Do not treat Syncthing, RAID, filesystem snapshots, or provider retention as
   substitutes for an independently restorable backup.
8. Do not make mutable UI state look declarative merely by hiding imperative
   commands in Nix activation hooks.
9. Refactors must preserve behavior and state paths. State migrations happen in
   separate phases with separate rollback plans.
10. Keep old disks and repositories untouched until application-level recovery
    acceptance checks pass.

## Current architecture to preserve

```text
Internet                    Tailnet
   |                           |
Cloudflare Tunnel        Tailscale Services
   |                           |
   +---------- loopback backends ----------+
                                            |
                  Native NixOS services on Kim
                    |              |
            PostgreSQL        filesystem state
            on root disk      /srv and /var/lib
                    \              /
                     application-aware Borg
                              |
                  local removable repository
```

The following existing choices are sound and should remain unless a later phase
provides a measured reason to change them:

- Focused application or tightly coupled stack modules under `homelab/`.
- Native NixOS services rather than moving everything into containers.
- Shared PostgreSQL over its Unix socket, with no TCP listener.
- Public services through Cloudflare and private services through Tailscale.
- Application backends bound to loopback.
- `/srv` mount dependencies that prevent fallback writes to the root disk.
- SOPS runtime secret files.
- Paperless's supported exporter and logical PostgreSQL backups.
- Provisioned Grafana dashboards and bounded Prometheus retention.
- A non-destructive Borg restore helper that only extracts into an existing
  empty directory.

## State ownership model

Every service must classify all of its state into exactly one of these groups:

| State class | Owner | Recovery rule |
| --- | --- | --- |
| Declarative configuration | Git + NixOS | Rebuild the archived revision |
| Encrypted secret | SOPS or external password manager | Decrypt at runtime; verify independent key recovery |
| Mutable primary data | Application DB/files | Back up consistently and restore with the matching application version |
| Disposable state | Reprovisioned cache/history | Exclude deliberately and document accepted loss |
| External control-plane state | Cloudflare, Tailscale, provider | Manage as code or document and audit drift |

A service is not considered recoverable until its mutable primary data has an
owner, backup representation, restore order, version constraint, and functional
acceptance check.

## Current service recovery matrix

| Service | Primary mutable state | Current representation | Required follow-up |
| --- | --- | --- | --- |
| Nextcloud | PostgreSQL and `/srv/nextcloud` | Logical dump plus file tree | Full version-matched restore runbook; inventory mutable store apps |
| Home Assistant | `/var/lib/hass` and PostgreSQL recorder | Quiesced tar plus logical dump | Restore drill for config, integrations, credentials, automations, and recorder |
| Immich | PostgreSQL and `/srv/immich` | Logical dump plus quiesced file tree | Version-matched database/storage restore, integrity scan, and mobile upload test |
| Media stack | Jellyfin, Servarr, Seerr, and qBittorrent/Mullvad control state | Quiesced `/var/lib` paths; downloaded media deliberately excluded | Restore application wiring and verify import, hardlinks, playback, transcoding, and VPN binding |
| Paperless | Export, pending consume files, PostgreSQL fallback | Supported exporter, consume path, logical dump | Keep exporter import as primary path; verify pending-file recovery |
| Miniflux | PostgreSQL | Logical dump | Database restore and login/feed validation |
| Vaultwarden | PostgreSQL and `/var/lib/bitwarden_rs` | Logical dump plus file tree | Verify RSA identity, attachments, Sends, and DB as one recovery point |
| Syncthing | Device identity/config and synchronized files | Home/config paths plus `/var/lib` coverage | Define restore-versus-repair policy before reconnecting peers |
| Uptime Kuma | `/var/lib/private/uptime-kuma` SQLite state (`/var/lib/uptime-kuma` is a DynamicUser symlink) | Quiesced file copy | Restore monitors and notification test; later consider online SQLite snapshot |
| T3 Code | `~/.local/share/t3code` SQLite/WAL, identity, keys, attachments, and worktrees | User-unit-quiesced file copy | Restore one version-matched tree; validate identity, workspace, attachment, and worktree behavior |
| Grafana | Local DB and generated secret key | Intentionally excluded | Confirm every important dashboard, datasource, alert, and role is provisioned |
| Prometheus | Local TSDB | Intentionally excluded | Accept loss of history; keep retention bounded |
| Tailscale | Node identity, ACLs, grants, Serve state | Partly external and partly imperative | Reconcile local Serve state; version and validate tailnet policy |
| Cloudflare | DNS, tunnel routes, Access/WAF policy | Tunnel ingress local; account state external | Manage provider state as code or add a drift audit |

## Phase 0: stabilize the live system before redesign

### Goal

Restore successful daily backups and remove the confirmed stale private ingress
without moving data.

### 0.1 Repair Borg's Home Assistant write path — Prepared

Problem: the sandboxed Borg unit uses `ProtectSystem=strict`. Daily jobs from
July 20 through July 31 failed when the pre-hook attempted to create
`/var/backup/home-assistant`.

Implementation:

1. Keep the archive directory in a shared constant in
   `modules/services/backup.nix`.
2. Add it through `services.borgbackup.jobs.main.readWritePaths` rather than
   overriding the generated systemd unit directly.
3. Create it declaratively through `systemd.tmpfiles.rules` with mode `0700` and
   root ownership.
4. Keep atomic `config.tar.tmp` creation and rename behavior.
5. Assert the evaluated Borg unit contains the write path.

Acceptance:

- A manual backup creates a fresh Home Assistant archive.
- `systemctl status borgbackup-job-main.service` reports success.
- A staged archive contains `var/backup/home-assistant/config.tar`.
- `tar -tf` can list the staged archive.

### 0.2 Close mutable-state backup races — Prepared

Implementation:

1. Include `/srv/paperless/consume` in Borg paths.
2. Keep `paperless-consumer.service` and `paperless-task-queue.service` stopped
   through the complete Borg file-copy phase.
3. Stop the Nextcloud mutable-app timer before backup.
4. Wait up to 30 minutes for an already-running Nextcloud app update instead of
   terminating it mid-write.
5. Keep Uptime Kuma stopped while `/var/lib/private/uptime-kuma` is copied.
6. Keep Vaultwarden stopped until both PostgreSQL and
   `/var/lib/bitwarden_rs` are captured.
7. Keep the T3 Code user unit stopped while its SQLite, identity, attachment,
   key, and worktree state is copied.
8. Restart archive-scoped units after archive creation, before Borg prune and
   compact.
9. Restart exactly the units that were active before backup, even after a
   failed pre-hook or Borg invocation.

Acceptance:

- Regression tests classify Paperless ingestion and Kuma as file-quiesced.
- A failed backup still returns all previously active services.
- A test file waiting in Paperless consume is present in the archive.
- Uptime Kuma monitors remain present after a staged restore test.

### 0.3 Reconcile stale Tailscale Services — Prepared

Problem: the live node still advertises `svc:buzz`; its old backend port `19003`
is now Vaultwarden's port.

Implementation:

1. Read `tailscale serve status --json` during reconciliation.
2. Enumerate the current `.Services` keys.
3. Clear named services absent from `lib/homelab.nix`.
4. Reapply every desired endpoint with explicit HTTPS listener and HTTP
   loopback backend semantics.
5. Leave machine-level Serve configuration untouched until task 0.6 is
   explicitly approved.
6. Retain bounded retries for tailscaled/control-plane readiness.

Acceptance:

- `svc:buzz` is absent after deployment.
- Every declared private service is present with its expected backend.
- Vaultwarden responds only through its intended service identity and hostname.
- Machine-level and named-service state are reported separately during audit.

### 0.4 Execute custom checks in CI — Prepared

Implementation:

1. Add a `regression-checks` CI job.
2. Build Tailscale, backup, Paperless, Homepage, monitoring, and Fleet
   regression derivations explicitly.
3. Keep the full Kim system build as a separate integration check.

Acceptance:

- A failing Nix assertion in a custom regression makes CI fail.
- The Kim build and regression jobs remain independently diagnosable.

### 0.5 Deploy and verify the stabilization patch — Pending approval

Preconditions:

- Review and isolate unrelated worktree changes before deployment.
- Record the current Git revision and current system generation.
- Confirm `/srv` and `/mnt/backups` are mounted from the expected devices.
- Confirm no destructive storage command is part of the deployment.

Deployment:

1. Run `make lint`.
2. Run `nix flake check --no-build --no-eval-cache`.
3. Build `.#nixosConfigurations.kim.config.system.build.toplevel`.
4. Apply with the repository's normal `make rebuild` workflow.
5. Start `borgbackup-job-main.service` manually rather than waiting for 03:00.
6. Inspect the service result and list the new archive.
7. Stage representative paths into a new empty directory.
8. Compare live and declared Tailscale named-service lists.

Required staged paths:

- `var/backup/home-assistant/config.tar`
- `var/backup/postgresql`
- `srv/immich`
- `srv/paperless/export`
- `srv/paperless/consume`
- `srv/paperless/media`
- `srv/nextcloud`
- `var/lib/bazarr`
- `var/lib/jellyfin`
- `var/lib/lidarr/.config/Lidarr`
- `var/lib/nixos-containers/qbt`
- `var/lib/private/jellyseerr`
- `var/lib/private/prowlarr`
- `var/lib/radarr/.config/Radarr`
- `var/lib/sabnzbd`
- `var/lib/sonarr/.config/NzbDrone`
- `var/lib/private/uptime-kuma`
- `var/lib/bitwarden_rs`
- the archived `nix-config` checkout

Rollback:

- If activation fails, return to the previous NixOS generation.
- If Borg fails, do not proceed to any later phase; preserve logs and verify all
  quiesced units restarted.
- A Nix generation rollback does not roll back an application database after an
  application migration. Phase 0 should not introduce application upgrades.

### 0.6 Remove unmanaged node-level Serve state — Migration complete; audit pending

The stale machine-level T3 Code handler was removed during the tailnet domain
migration on 2026-08-01. `svc:t3code` is now the sole browser endpoint.

Migration result:

1. The unmanaged machine-level Serve configuration was removed.
2. All declared named services were recreated under the current tailnet domain.
3. The T3 Code endpoint and local backend were verified after migration.

Follow-up: add a live audit that fails when machine-level Serve handlers are
present without an explicit declaration.

## Phase 1: prove local recovery

### Goal

Demonstrate that current archives restore applications, not merely that Borg can
read its repository.

### 1.1 Add archive metadata

Implementation:

1. Create `/var/backup/homelab/manifest.json` during backup preparation.
2. Record no secrets. Include:
   - Git revision or dirty-state marker;
   - NixOS system version;
   - PostgreSQL major version;
   - application package versions;
   - backup start timestamp;
   - expected database names;
   - expected primary state paths;
   - disposable-state declarations.
3. Create the directory through tmpfiles and add the narrow Borg write path.
4. Include the manifest in every archive.
5. Validate the JSON in a regression test.

Acceptance:

- An operator can identify the exact configuration and application versions to
  restore before starting any application.

### 1.2 Add a complete recovery runbook

Create `docs/homelab-recovery.md` with these sections:

1. Retrieve repository credentials from the independent recovery kit.
2. Build the archived Nix revision without starting stateful services.
3. Stage files into an empty directory.
4. Restore PostgreSQL roles/databases into the matching major version.
5. Restore each service in dependency order.
6. Apply ownership and mode checks.
7. Run application-specific repair/migration commands only after matching state
   is in place.
8. Validate functionality before exposing ingress.
9. Regenerate tokens intentionally omitted from portable exports.
10. Destroy staged plaintext after recording the drill result.

The runbook must contain separate procedures for:

- Nextcloud database/files/apps and `occ` checks.
- Home Assistant config plus recorder database.
- Paperless exporter import, with the database route documented only as an
  alternative that must never be combined with exporter import.
- Vaultwarden database, identity, attachments, and Sends.
- Miniflux database.
- Syncthing identity and safe peer reconnection.
- Uptime Kuma SQLite state and notification test.
- T3 Code SQLite, identity, keys, attachments, and worktrees.
- Intentionally disposable Grafana and Prometheus state.

### 1.3 Add safe recovery inspection tooling

Implementation:

1. Keep `borg-restore-main` extraction-only and non-destructive.
2. Add a read-only `homelab-backup-inspect` command that:
   - lists archive metadata;
   - checks required members exist;
   - validates the Home Assistant tar structure;
   - lists PostgreSQL dump files;
   - reports, but never restores, missing expected paths.
3. Never add a one-command production restore that overwrites live paths.
4. Add shell regression tests using fixture archive listings.

### 1.4 Perform and record a quarterly restore drill

Implementation:

1. Restore into a disposable VM, spare host, or isolated namespace with separate
   ports and databases.
2. Use the archived application versions first.
3. Record archive name, Git revision, versions, checks performed, failures, and
   elapsed recovery time.
4. Store the result outside Kim as well as in the repository documentation.
5. Create a recurring operational reminder after the first successful drill.

Completion gate:

- Paperless import succeeds and document counts/files/search work.
- A PostgreSQL dump restores into an isolated cluster.
- Home Assistant loads its config and recorder data.
- Nextcloud opens representative files and calendar data.
- Vaultwarden opens representative vault items and attachments.
- Uptime Kuma retains monitors and can send a test notification.
- T3 Code retains its identity and can open workspaces, attachments, and
  worktrees.

## Phase 2: establish independent disaster recovery

### Goal

Recover after loss of Kim, the local backup drive, or access to 1Password.

### 2.1 Add an offline Age identity — External decision

Implementation:

1. Generate the private identity on an offline machine or encrypted removable
   medium.
2. Store it outside Kim and outside 1Password.
3. Add only its public recipient to `.sops.yaml`.
4. Run `sops updatekeys secrets/secrets.yaml` while an existing identity is
   still available.
5. Verify the offline identity decrypts a copy of the SOPS file on a separate
   machine.
6. Keep a separately secured Borg passphrase and written recovery instructions
   in the same recovery kit.

Never place the offline private identity in Git or inside the Borg repository it
is needed to unlock.

### 2.2 Add an off-site encrypted backup — External decision

Provider requirements:

- Physically and administratively separate from Kim.
- Encryption keys controlled by the user.
- Retention or object versioning that prevents a local deletion from
  immediately deleting every remote recovery point.
- Supported integrity checking and restore from a separate machine.
- Predictable storage and egress cost.

Implementation options must be reviewed after provider selection:

1. **Direct second Borg repository:** simplest recovery semantics, but copying
   live file state requires another quiesced backup window.
2. **Quiescent mirror of the completed local Borg repository:** avoids a second
   application outage, but the mirror must run only when no Borg job/check is
   mutating the repository and the destination should provide versioning.
3. **Filesystem snapshots followed by two independent repository writes:** best
   application uptime, but requires a later snapshot-capable storage design and
   must not block near-term off-site protection.

Near-term implementation should prefer the smallest approach that can be fully
restored and checked. Do not introduce an unverified repository-copy mechanism
solely to avoid a short maintenance window.

Required Nix changes after selection:

- Add typed off-site repository options to `custom.backup`.
- Provide credentials through SOPS runtime files.
- Pin and verify the remote SSH host key when applicable.
- Add systemd ordering so local backup, off-site copy, and Borg checks cannot
  mutate/read an inconsistent repository concurrently.
- Use separate retention credentials where the provider supports append-only
  backup writers.
- Add an independent remote consistency-check schedule.

Acceptance:

- A separate machine can list and extract the off-site repository using only
  the recovery kit.
- Loss of Kim and `/mnt/backups` is no longer fatal.
- A local archive deletion does not immediately destroy all remote history.

### 2.3 Add an external dead-man monitor — External decision

Implementation:

1. Choose a service reachable independently of Kim.
2. Store ping URLs/tokens in SOPS.
3. Send a start signal when backup begins, a success signal only after archive
   creation and service recovery, and a failure signal from the failure path
   when supported.
4. Alert when no success arrives within the expected daily window.
5. Add a separate heartbeat for total host/network availability if desired.
6. Test by intentionally withholding one heartbeat; do not assume delivery.

## Phase 3: introduce a typed homelab service inventory

### Goal

Eliminate drift between endpoint, backup, storage, monitoring, and presentation
lists without creating a monolithic implementation module.

### 3.1 Define raw service records

Add a data-only inventory, following the existing host pattern:

- `lib/homelab-services.nix`: raw service records only.
- `lib/homelab-inventory.nix`: defaults, normalization, unknown-field rejection,
  and cross-service validation.
- `lib/homelab.nix`: small derived interfaces for existing consumers.

Suggested record shape:

```nix
vaultwarden = {
  endpoint = {
    exposure = "tailnet";
    port = 19003;
    monitorPath = "/alive";
    authorizationOwner = "tailscale-grants";
  };
  state = {
    paths = ["/var/lib/bitwarden_rs"];
    database = "vaultwarden";
  };
  backup.quiesce = [
    {
      scope = "system";
      unit = "vaultwarden.service";
      until = "archive";
    }
  ];
  operations.units = ["vaultwarden.service"];
  recovery = {
    order = 40;
    versionPolicy = "restore-archived-version-first";
    runbook = "docs/homelab-recovery.md#vaultwarden";
    acceptance = [
      "representative-item-and-attachment-open"
      "send-and-rsa-identity-verified"
    ];
  };
};
```

Allowed exposure values:

- `public`
- `tailnet`
- `local`
- `none`

State kinds are derived from `state.paths`, `state.database`, and
`state.disposable` rather than entered independently:

- `none`
- `files`
- `database`
- `database+files`
- `disposable`

Ordinary file paths and the shared PostgreSQL dump are also derived. Only
exceptional backup behavior is explicit:

- `direct`: archive declared files and/or the shared database dump.
- `archive-transform`: replace live state with a generated archive artifact.
- `application-export`: retain declared state and an application export.

Allowed quiesce phases:

- `dump`: restart after logical database/export artifacts are complete.
- `archive`: remain stopped until Borg file capture is complete.

Quiesce entries may target `system` units or a named user's `user` manager.

Keep service-specific preparation implementation, such as the Home Assistant tar
and Paperless exporter invocation, inside the backup module. The inventory
describes required state and lifecycle; it does not contain shell scripts.

### 3.2 Add inventory validation

Reject evaluation when:

- Unknown record fields are present.
- Ports collide, including health/path backends.
- A public endpoint lacks an explicit hostname.
- A stateful service has no valid derived or explicit backup strategy.
- A transformed/exported service omits its generated artifact.
- A `/srv` state path does not declare the storage dependency.
- A tailnet service lacks a generated Tailscale service name.
- A monitored service has no important unit or explicit monitor exception.
- A disposable service also claims required recovery data.
- A stateful service lacks recovery ownership, ordering, version policy,
  runbook, or functional acceptance checks.
- An exposed service lacks authorization ownership.
- A user-scoped quiesce entry lacks a user.
- A declared system or user unit is absent from Kim's evaluated configuration.
- A `/srv` dependency targets a generated empty unit instead of a real service.

### 3.3 Migrate consumers one at a time

Perform this as a behavior-preserving refactor with a green check after every
adapter:

1. Endpoint derivation in `lib/homelab.nix`.
2. `homelab/tailscale-serve.nix` from `exposure = "tailnet"`.
3. `homelab/cloudflared.nix` from `exposure = "public"`.
4. `homelab/homepage.nix` from presentation metadata, while retaining private
   Homepage-specific card helpers.
5. `homelab/storage.nix` from declared `/srv` consumers.
6. `modules/services/backup.nix` from state paths and quiesce phase metadata.
7. `homelab/monitoring.nix` from important-unit metadata.

Do not migrate all adapters in one unreviewable commit.

### 3.4 Keep ownership local

The typed inventory must not absorb:

- Application package/options configuration.
- Arbitrary systemd implementation details.
- Secret values or secret file contents.
- Backup shell bodies.
- Grafana dashboard JSON.
- Provider credentials or Terraform state.
- Every Homepage presentation detail when Homepage is the only consumer.

Completion gate:

- Adding a stateful service requires one service record plus its owning Nix
  module, not edits to five unrelated lists.
- Removing a service removes ingress, monitoring, and backup expectations or
  fails evaluation with a clear ownership error.

## Phase 4: implement actionable monitoring and alerts

### Goal

Turn existing dashboards into alerts that reach a person outside Kim.

### 4.1 Export backup freshness

Implementation:

1. Enable the node exporter's textfile collector with a dedicated root-writable
   directory.
2. Write metrics atomically only after successful backup and cleanup:
   - `homelab_backup_last_success_timestamp_seconds`
   - `homelab_backup_last_duration_seconds`
   - `homelab_backup_last_archive_size_bytes` when cheaply available
3. Add analogous last-success metadata for Borg consistency checks and off-site
   replication.
4. Never update success timestamps on a partial or cleanup-failed run.
5. Add dashboard panels for backup and check age.

### 4.2 Add Prometheus rules

Start with a small, high-signal rule set:

- Daily backup stale or failed.
- Weekly Borg check stale or failed.
- Off-site copy stale or failed.
- `/srv` absent.
- Root or `/srv` capacity above warning/critical thresholds.
- SMART health failure or dangerous NVMe temperature.
- PostgreSQL exporter down.
- Important systemd unit failed.
- Public ingress or Tailscale Serve unavailable for a sustained interval.
- Repeated service restart growth.

Use `for` durations to avoid alerting on ordinary restart and backup windows.

### 4.3 Add alert delivery

Implementation:

1. Choose Alertmanager plus a supported external destination, or use the
   existing Apprise capability if it can be provisioned and tested cleanly.
2. Keep notification credentials in SOPS.
3. Provision routing and receivers declaratively.
4. Send a test alert during rollout.
5. Keep the external dead-man monitor from Phase 2; local Alertmanager cannot
   report total loss of Kim.

### 4.4 Reduce monitoring blind spots

Current safe behavior stops Uptime Kuma for the whole Borg file-copy window.
After recovery is proven, evaluate an application-consistent SQLite online
backup or brief stop-and-copy artifact so Kuma can restart before Borg uploads
the rest of the archive. Keep the full quiesce behavior unless the replacement
is tested by restoring monitor and notification state.

## Phase 5: make ingress and authorization ownership explicit

### Goal

Make the effective public/private policy reviewable, not only the local proxy
configuration.

### 5.1 Version Tailscale policy — External decision

Implementation:

1. Export and review current tailnet users, devices, tags, service ownership,
   ACLs, and grants.
2. Define expected grants per `svc:*`, especially Vaultwarden, Paperless,
   Grafana, and T3 Code.
3. Store the policy in a version-controlled provider configuration or dedicated
   policy file.
4. Validate policy syntax and lockout-sensitive changes in CI.
5. Add a read-only drift check against live service ownership/grants.
6. Test one intended and one unauthorized identity for every sensitive service.

### 5.2 Manage Cloudflare account state — External decision

Use OpenTofu/Terraform or an equivalent reviewed provider layer for:

- DNS records.
- Tunnel routes.
- Access policies when appropriate.
- WAF and rate-limit policy.
- Provider token scope.

Keep the local `cloudflared.nix` ingress allow-list and 404 fallback. Provider
state complements local configuration; it does not replace origin security.

Store provider state remotely with locking and recovery. Do not commit API
tokens or Terraform state containing secrets.

### 5.3 Add ingress regression coverage

Add checks that prove:

- Only Nextcloud and Home Assistant are in public ingress.
- Public origins use loopback and the expected Host header.
- Undeclared public hosts reach the 404 fallback.
- Every tailnet backend binds loopback.
- Removed named services are reconciled.
- Node-level Serve handlers are either explicitly owned or absent.
- Public application trusted-proxy lists remain loopback-only.

## Phase 6: tighten host and application security

### 6.1 Grafana authorization

Current proxy-authenticated users receive Editor access. Decide whether every
identity authorized for `svc:grafana` needs Explore/dashboard mutation.

Preferred implementation:

1. Default new users to Viewer.
2. Grant Editor/Admin only to explicit identities or groups through a supported
   provisioned mechanism.
3. Test that client-supplied `Tailscale-User-Login` cannot override Tailscale's
   injected identity.
4. Preserve anonymous/basic/login-form disablement.

### 6.2 Nextcloud private-network egress

`allow_local_remote_servers = true` enables the Paperless integration but
broadens server-side request access.

Implementation options:

1. Prefer a narrowly restricted local proxy that can reach only the Paperless
   hostname/path required by the integration.
2. If no narrow supported approach exists, retain the setting as an explicit
   accepted risk, limit installed apps, and add it to security review notes.
3. Do not silently remove it and break the integration.

### 6.3 Syncthing network policy

Decide whether LAN discovery/transport is intentional.

- If synchronization should be tailnet-only, restrict transport ports to
  `tailscale0`, disable LAN discovery, and keep the GUI loopback-only.
- If LAN synchronization is intentional, document the exception and add a
  firewall test proving only Syncthing's required ports are reachable on the
  physical interface.
- Prefer explicit GUI host acceptance over `insecureSkipHostcheck` if the
  current Syncthing version supports the Tailscale hostname cleanly.

### 6.4 Docker exposure and privilege

Implementation:

1. Inventory all published container ports and Docker-created firewall rules.
2. Add a read-only unexpected-listener check.
3. Move long-lived production applications into NixOS modules rather than ad-hoc
   Docker containers.
4. Evaluate rootless Docker/Podman for development workloads.
5. Treat membership in the `docker` group as root-equivalent and document why
   it remains necessary if retained.

### 6.5 Fleet agent forwarding

Implementation:

1. Change Fleet's default `ForwardAgent` to `no`.
2. Enable it only for explicit aliases/workflows that require onward SSH.
3. Preserve `ForwardAgent=no` for port-forward commands.
4. Extend Fleet regression tests to pin the default.

### 6.6 Host identity recovery

Classify these identities explicitly:

- SSH host key: preserve securely or document deliberate rotation.
- Tailscale node identity: restore versus re-enroll decision.
- Syncthing device identity: normally restore before reconnecting peers.
- Vaultwarden RSA identity: restore with file state.
- Cloudflare tunnel credentials: recover from SOPS/provider.
- machine-id: normally regenerate on a replacement installation.

Do not restore all of `/var/lib` blindly across architectures merely because it
was backed up.

## Phase 7: improve storage declarations without endangering data

### Goal

Make fresh provisioning reproducible while keeping destructive layout logic
separate from live mounts.

### 7.1 Correct hardware documentation

Implementation:

1. Reconcile comments in `homelab/storage.nix`,
   `machines/hardware/kim-disko.nix`, and monitoring with live `lsblk` output.
2. Record stable model, serial, filesystem UUID, and role for root, `/srv`, and
   backup devices.
3. Prefer stable by-ID references for destructive Disko layouts.
4. Prefer UUID or another unique identifier for live mounts; avoid ambiguous
   duplicate labels.

This is documentation/mount-identity work, not a reformat.

### 7.2 Separate live mounts from first-provision layouts

Keep:

- `machines/hardware/kim.nix` and `homelab/storage.nix` as non-destructive live
  mount declarations.
- Disko layouts outside normal imports and explicitly destructive.

Add two documented workflows:

1. Attach an existing data disk without formatting it.
2. Provision a confirmed blank replacement disk.

Every destructive example must require `lsblk`, stable by-ID review, a dry run,
and a typed confirmation of the exact device.

### 7.3 Optional encryption/filesystem migration — Destructive gate

Do not begin until Phases 1 and 2 have passed.

Decision criteria:

- Add LUKS2 encryption if physical-loss confidentiality is required.
- Keep ext4 if snapshots are not needed; ext4 plus tested Borg is simpler and
  already understood.
- Choose Btrfs/LVM snapshots only when the operational benefit justifies scrub,
  monitoring, and recovery complexity.
- Do not choose a filesystem because it appears more declarative.

Migration sequence:

1. Freeze application changes.
2. Produce and verify final local and off-site archives.
3. Disconnect at least one verified backup physically.
4. Record disk identities and versions.
5. Provision only the reviewed replacement target.
6. Rebuild the archived configuration revision first.
7. Restore into empty paths with services disabled.
8. Validate every application.
9. Create a fresh backup from the new host.
10. Retain the old disk unchanged until the new backup and restore checks pass.

## Phase 8: broaden automated verification

### Evaluation regressions

Add or extend tests for:

- Typed inventory unknown fields and enum validation.
- Unique ports and hostnames.
- Stateful-service backup/disposable classification completeness.
- `/srv` dependency derivation.
- Backup quiesce phase derivation.
- Cloudflare ingress allow-list and fallback.
- Tailscale stale-service reconciliation.
- Final loopback bindings and closed application firewall ports.
- Grafana role/auth policy.
- Syncthing interface policy.
- Fleet agent-forwarding default.
- Archive metadata contents.

### Backup coordinator test

Create a test harness with fake systemd/application commands that exercises:

1. Normal backup lifecycle.
2. Failure before exports.
3. Failure during Home Assistant archive creation.
4. PostgreSQL dump failure.
5. Borg create failure.
6. One service failing to restart.
7. A pre-existing inactive service remaining inactive.
8. Nextcloud updater timeout.

The test must prove cleanup order and final exit status without requiring live
production data.

### Runtime smoke checks

Add a `homelab-check` command that is read-only and reports:

- Required mounts and backing devices.
- Failed important units.
- Listener/bind-address drift.
- Tailscale named-service drift.
- Cloudflare tunnel unit health.
- Prometheus target health.
- Last backup/check/off-site success age.
- Expected backup archive members only when explicitly opted in as root; this
  can attach the backup automount and is separate from the default smoke check.

By default it must not restart services, clear ingress, attach automounts, or
restore data.

## Phase 9: documentation and operational ownership

Update:

- `docs/config-ownership-and-recovery.md` with the five state classes.
- `docs/beelink-headless-checklist.md` with backup freshness, inventory drift,
  and restore-drill checks.
- `BOOTSTRAP.md` with a link to the full homelab recovery order rather than the
  generic instruction to restore “anything needed.”
- `docs/paperless.md` with pending consume-file verification.
- A new `docs/homelab-recovery.md` with service-level restore procedures.
- The homelab README section with the typed inventory interface and rules for
  adding/removing a service.

Document the service-addition checklist:

1. Add the NixOS application module.
2. Add one typed service record.
3. Classify every mutable path/database/secret/disposable artifact.
4. Declare exposure and authorization owner.
5. Add health and important units.
6. Add backup and restore acceptance checks.
7. Verify removal reconciliation as well as addition.

## Implementation order and dependency gates

| Order | Work | May change data layout? | Gate to continue |
| --- | --- | --- | --- |
| 0 | Deploy prepared backup/Tailscale/CI safety patch | No | Fresh local archive and staged extraction succeed |
| 1 | Complete local restore runbooks and drills | No | Core applications restore in isolation |
| 2 | Offline Age identity, off-site backup, external dead-man | No | Separate-machine off-site extraction succeeds |
| 3 | Typed service inventory refactor | No | Behavior and evaluated config remain equivalent |
| 4 | Backup metrics, alerts, and external delivery | No | Test alert and stale-backup alert are received |
| 5 | Provider IaC and security tightening | No, except access policy | Intended access works; unauthorized access fails |
| 6 | Hardware documentation and provisioning separation | No | Live mount/device audit passes |
| 7 | Optional encryption/filesystem migration | Yes | Two verified backups and full restore drill exist |
| 8 | Continuous verification and operational docs | No | CI and quarterly process cover every stateful service |

## Definition of done

The architecture work is complete when:

- The latest local and off-site backup timestamps are externally observable.
- A separate machine can decrypt SOPS and extract the off-site repository.
- Every stateful service has a typed state and recovery classification.
- Adding or removing a service cannot silently omit backup, storage, monitoring,
  or ingress cleanup.
- Tailscale and Cloudflare effective policy are versioned or have an explicit
  automated drift report.
- A complete recovery drill has restored the major applications from an
  archived revision.
- No critical service depends on an undocumented UI-only setting without a
  backup and restore procedure.
- Storage replacement can be performed from reviewed instructions without
  guessing device names or formatting the source disk.
- Quarterly restore drills and security/provider audits have named owners and
  recorded results.
