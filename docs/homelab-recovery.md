# Kim homelab recovery

This runbook restores application state from a Borg archive. It is deliberately
not a one-command restore. Every extraction goes to a new empty staging
directory, and every stateful service stays stopped until its matching files and
database are ready.

Record each drill in a dated file under `docs/restore-drills/` and copy the
record outside Kim. Record the archive, Git revision, package versions, checks,
failures, elapsed time, and operator.

## 1. Retrieve the independent recovery kit

The kit must contain, outside Kim and outside the Borg repository:

- the Borg passphrase and repository location;
- an Age identity able to decrypt `secrets/secrets.yaml`;
- written provider/account recovery instructions;
- the expected off-site repository fingerprint or pinned SSH host key.

On a separate machine, verify that the Age identity decrypts a copy of the SOPS
file and that Borg can list the selected repository. Do not copy private keys
into Git or a restore-drill record.

## 2. Identify and build the archived revision

List archives, then inspect one without restoring it:

```sh
sudo borg-job-main list
sudo homelab-backup-inspect <archive>
```

The inspector prints `var/backup/homelab/manifest.json`. Record its Git
revision, dirty marker, NixOS version, PostgreSQL major version, and application
versions. A dirty archive requires reviewing the archived `nix-config` checkout
rather than assuming its `HEAD` fully describes the running system.

Stage only the checkout first and build it; a build does not start services:

```sh
install -d -m 0700 /var/tmp/homelab-restore
sudo borg-restore-main <archive> /var/tmp/homelab-restore home/maxpw/nix-config
cd /var/tmp/homelab-restore/home/maxpw/nix-config
nix build .#nixosConfigurations.kim.config.system.build.toplevel
```

Use the archived package versions first. Do not upgrade an application as part
of the initial restore.

Before activating a replacement Kim configuration, mask the stateful services,
backup jobs, and ingress in the recovery environment. This prevents an empty
application from initializing an intended restore destination:

```sh
sudo systemctl mask --runtime \
  cloudflared-tunnel-5b712ae4-3ce4-4499-9cb7-a57cde1c571f.service \
  tailscale-serve.service borgbackup-job-main.service \
  actual.service atuin.service autobrr.service cross-seed.service \
  home-assistant.service homelab-mcp.service nextcloud-cron.service nextcloud-cron.timer \
  forgejo-runner.service forgejo-runner-register.service forgejo.service \
  nextcloud-setup.service nextcloud-update-db.service \
  nextcloud-update-store-apps.service nextcloud-update-store-apps.timer \
  phpfpm-nextcloud.service paperless-consumer.service \
  paperless-exporter.service paperless-scheduler.service \
  paperless-task-queue.service paperless-web.service miniflux.service \
  immich-machine-learning.service immich-server.service leerr.service \
  bazarr.service jellyfin.service lidarr.service plex.service prowlarr.service \
  radarr.service seerr.service sonarr.service tunarr.service \
  container@qbt.service container@sab.service \
  qbittorrent-proxy.service qbittorrent-proxy.socket \
  sabnzbd-proxy.service sabnzbd-proxy.socket \
  syncthing.service uptime-kuma.service vaultwarden.service \
  docker-executor.service docker-kometa.service docker-maintainerr.service \
  docker-tdarr.service portfolio-tracker-api.service \
  portfolio-tracker-sync.service portfolio-tracker-sync.timer \
  recyclarr.service recyclarr.timer unpackerr.service
```

The quiesce units in `homelab/inventory/services.nix` (`backup.quiesce` and
`operations.units`) are the source of truth; add any new stateful unit here.

Also keep `t3code.service` stopped in `maxpw`'s user manager while restoring its
state.

Use separate ports, databases, DNS, and Tailscale identity for a drill. Never
expose a drill instance through production ingress.

## 3. Stage the complete recovery point

Create a second empty directory and extract the required members. Never point
`borg-restore-main` at `/`, `/srv`, `/var/lib`, or any live service path. The
archive's own manifest lists every path it was expected to contain, so stage
from that list rather than from the current checkout. Reconcile the selection
with the manifest's transforms, application versions, and owning service
runbooks before restoring anything.

```sh
sudo install -d -m 0700 /var/tmp/homelab-manifest /var/tmp/homelab-state
sudo borg-restore-main <archive> /var/tmp/homelab-manifest var/backup/homelab/manifest.json
mapfile -t paths < <(sudo jq -r '.expectedArchivePaths[] | ltrimstr("/")' \
  /var/tmp/homelab-manifest/var/backup/homelab/manifest.json)
sudo borg-restore-main <archive> /var/tmp/homelab-state "${paths[@]}"
sudo homelab-backup-inspect <archive>
```

Keep the manifest, database dumps, and file trees from this same archive. Do not
mix a newer database with older files or exports.

## 4. Restore PostgreSQL first

Use an empty isolated cluster running the manifest's PostgreSQL **major**
version. Keep application services stopped. Inspect the staged dump names and
format before piping anything into `psql`.

For the current compressed `pg_dumpall` representation, the recovery shape is:

```sh
sudo -u postgres zstdcat \
  /var/tmp/homelab-state/var/backup/postgresql/all.sql.zstd \
  | sudo -u postgres psql --set ON_ERROR_STOP=on postgres
```

If the archive contains per-database custom dumps instead, create the recorded
roles/databases and use `pg_restore --exit-on-error`. Do not guess the format.
Confirm that `atuin`, `forgejo`, `hass`, `immich`, `miniflux`, `nextcloud`,
`paperless`, and `vaultwarden` exist with their expected owners. Restore files before starting
applications.

Choose the Paperless route immediately after this restore:

- **Exporter route (preferred):** drop only the restored `paperless` database,
  recreate it empty with owner `paperless`, then run the exporter import below.
  The role comes from the same `pg_dumpall` recovery point.
- **Database route:** keep the restored `paperless` database and restore the
  matching staged `srv/paperless/media` tree. Do not run `document_importer`.

For example, the exporter branch on the isolated cluster is:

```sh
sudo -u postgres dropdb paperless
sudo -u postgres createdb --owner=paperless paperless
```

Never import the exporter over the restored Paperless database.

## 5. Restore services in dependency order

For a real replacement, copy from staging into an explicitly created, empty
destination with `rsync -aHAX --numeric-ids`, then compare owner, group, and mode
against staging before unmasking anything. If a destination is not empty, stop
and determine who initialized it; do not merge blindly.

### Nextcloud

1. Keep Nextcloud cron, PHP-FPM, nginx ingress, and the store-app updater
   stopped. Restore the `nextcloud` database and `/srv/nextcloud` from the same
   archive.
2. Verify the `nextcloud` owner, Redis/socket access, `config`, `data`, and
   mutable `store-apps` trees. Inventory every mutable app in `store-apps`.
3. Start PostgreSQL and Redis, then run version-matched checks as the Nextcloud
   user:

   ```sh
   sudo -u nextcloud nextcloud-occ status
   sudo -u nextcloud nextcloud-occ maintenance:repair
   sudo nextcloud-app-ownership-check
   ```

4. Run `files:scan` only when file-cache validation shows it is necessary.
   Open representative files and verify calendar data before enabling public
   ingress.

### Home Assistant

1. Keep Home Assistant stopped and restore the matching `hass` recorder
   database.
2. Validate and extract the nested archive into another empty staging
   directory, never directly into `/var/lib`:

   ```sh
   mkdir /var/tmp/home-assistant-config
   tar -tf /var/tmp/homelab-state/var/backup/home-assistant/config.tar
   tar -xf /var/tmp/homelab-state/var/backup/home-assistant/config.tar \
     -C /var/tmp/home-assistant-config
   ```

3. Copy the staged `hass` tree to an empty `/var/lib/hass`, preserve its owner
   and modes, then start Home Assistant on an isolated port.
4. Verify configuration loading, integrations, credentials, automations, and
   representative recorder history. Test a harmless automation before
   restoring public ingress.

### Immich

1. Keep both Immich units stopped. Restore the `immich` database and the
   complete staged `/srv/immich` tree from the same archive into an empty
   destination owned by `immich:immich` with mode `0700`.
2. Start with the package version recorded at `applicationVersions.immich`.
   Bring up PostgreSQL and Redis, then the machine-learning and server units on
   isolated tailnet ingress.
3. In Administration, run the storage integrity checks. Confirm there are no
   missing or offline files, then open representative originals, thumbnails,
   and videos.
4. Upload one photo from the mobile app and require thumbnail generation, face
   detection, and smart search to complete before restoring production ingress.
   Retain the untouched staged tree until those checks pass.

### Media stack

Keep every media reader and writer stopped, including Jellyfin, Plex, Tunarr,
the Servarr services, both downloader containers, and both host proxies, while
restoring their matching control state from the selected archive.
`/srv/media` is excluded from Borg and is recoverable only from a separate copy;
otherwise leave it empty and reconcile missing entries after the control plane
is healthy.

1. Restore and mount `/srv` before starting any media service.
2. Restore `/var/lib/nixos-containers/{qbt,sab}` and `/var/lib/sabnzbd` with
   the other control-state paths.
3. Start `container@qbt` and `container@sab`. Confirm Mullvad is connected in
   each namespace before qBittorrent and SABnzbd run or their host proxy
   sockets are unmasked. If a Mullvad device credential was lost or revoked,
   log in again inside that container; never write the account number to a
   file, the Nix store or shell history.
4. Start Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, Jellyfin, Plex, Tunarr and
   Seerr. Confirm the Usenet provider still uses port 563, SSL and strict
   certificate verification before resuming its queue.
5. Reconcile missing files in the library managers rather than trusting their
   restored databases.

### Media companions

Restore the Servarr managers first: Recyclarr and Unpackerr reuse their API
keys. Required state is `/var/lib/recyclarr`, `/var/lib/unpackerr`,
`/var/lib/private/autobrr`, `/var/lib/autobrr-session`, `/var/lib/cross-seed`,
`/var/lib/kometa`, `/var/lib/maintainerr` and `/var/lib/tdarr`, with the archived
package versions or image digests. Keep Tdarr paused and Maintainerr actions
inactive until the private integration files, Plex/TMDb connections and rule
definitions check out, then verify autobrr filters, cross-seed matches and
Recyclarr profiles.

### Homelab MCP

Stop `homelab-mcp.service` and restore the whole `/var/lib/private/homelab-mcp`
directory: `homelab-mcp.sqlite` is unreadable without its `secret-key`. Restore
the archived package version before any schema upgrade, restore Executor (below),
then verify an authenticated `media_stack_health` call through Executor.

### Portfolio tracker

Restore `/var/lib/portfolio-tracker` as one recovery point with both services
stopped: `portfolio.sqlite` (history, prices, run log), `pytr/all_events.json`
and the `.pytr/` Trade Republic session. Start the archived version and run a
sync; it must reconcile both accounts and `get_summary` must work through
Executor. Log in again if the session did not survive. History is rebuilt from
Trade Republic's timeline, but price history exists only in the database.

### Paperless

The supported exporter is the primary portable recovery route:

1. Provision the archived Paperless version with an empty database and empty
   media/data paths. Keep consumers and web ingress stopped.
2. Import only the staged exporter:

   ```sh
   sudo paperless-manage document_importer \
     /var/tmp/homelab-state/srv/paperless/export
   sudo paperless-manage document_sanity_checker
   ```

3. Restore pending files from `srv/paperless/consume` before enabling the
   consumer. Record their names and verify they are ingested after acceptance.
4. Compare document, correspondent, tag, and document-type counts; test search;
   open originals and archived files; and process one Tika-backed Office file.
5. Regenerate the Nextcloud integration API token, which is intentionally not
   in the portable export.

Alternative: restore the matching Paperless database plus all matching media
and data files. Never combine that route with an exporter import.

### Vaultwarden

1. Keep Vaultwarden stopped. Restore the `vaultwarden` database and the complete
   staged `/var/lib/bitwarden_rs` tree as one recovery point.
2. Verify the RSA identity files, attachments, and Sends are present with
   restrictive ownership and modes before starting the service.
3. Log in through isolated ingress; open representative vault items and an
   attachment; verify a Send; and confirm the service identity did not rotate.

### Actual Budget

Actual is served at `https://actual.maximilian.pw` through the existing Cloudflare
Tunnel, with application-owned password authentication. The server remains on
Kim at `127.0.0.1:19006`; budget state and backups remain in `/var/lib/actual`.
The inventory removes Actual from Tailscale Serve when the configuration is
activated. DNS is managed outside this flake: before cutover, ensure a proxied
CNAME for `actual.maximilian.pw` targets
`5b712ae4-3ce4-4499-9cb7-a57cde1c571f.cfargotunnel.com`. DNS changes and host
activation require explicit operator approval. Verify the existing server
password is set before exposing the service; do not publish an uninitialized
instance. After cutover, verify `/health`, password login, and budget sync over
the public HTTPS URL. Update clients and any registered bank-sync OAuth callback
to the new hostname; do not copy or delete server state for this ingress change.

Keep `actual.service` stopped and restore the complete staged
`/var/lib/actual` directory. Its `server-files/account.sqlite` contains the
hashed server password, registered budget files, and active session state;
`user-files` contains the synchronized budget blobs. Preserve the complete tree
as one recovery point and start the Actual package version recorded at
`applicationVersions.actual` on loopback. Sign in with the existing server
password, open a representative budget, and verify a client can synchronize
before enabling Cloudflare ingress. If end-to-end encryption is enabled for a
budget, its encryption password is separate recovery material and is not
recoverable from the server state.

### Executor

Keep `docker-executor.service` stopped and restore the complete staged
`/var/lib/executor-v2` directory. V2 stores its PGlite database, app source,
builds, app data, `auth-secret.key`, and `encryption.key` together; restoring only
the database is insufficient. Preserve numeric ownership (the pinned image's
`executor` user is UID/GID 1000) and restrictive modes. Start the image reference
recorded at `applicationVersions.executor` on loopback before attempting an
upgrade. The service refuses to start without both saved key files. Check
`http://127.0.0.1:19005/health`, sign in as the existing administrator, verify
apps, account links and approval policies, then make one harmless read-only tool
call through the MCP endpoint.

Do not expose an empty replacement instance: its first account would become the
new owner and newly generated keys could not decrypt archived credentials.

### Forgejo

Restore the `forgejo` PostgreSQL database together with `/srv/forgejo` and
`/var/lib/forgejo-runner-registration` from the same archive, keeping ownership
and modes. Use the archived Forgejo version before allowing its migrations.
Keep the runner stopped until Forgejo is healthy on tailnet ingress, the
administrator can sign in, and a private repository clones over HTTPS and SSH.
Then start the registration service and runner, confirm the runner UUID matches
the archive, and run a harmless container job. A lost registration produces a
new runner identity; remove the stale entry in Forgejo.

### Miniflux

Restore the `miniflux` database, start the archived package on loopback, log in,
open representative feeds, refresh one feed, and verify read/starred state and
custom preferences.

### Atuin

Keep `atuin.service` stopped and restore the `atuin` database and its role from
the shared PostgreSQL dump. The backup coordinator stops Atuin until the dump
completes. Start the package recorded at `applicationVersions.atuin` first,
with registration closed, on isolated ingress. The database contains account
and session state plus encrypted history; the client encryption key must be
recovered separately from 1Password. Do not generate a replacement key for an
existing account or merge live client SQLite files using file sync.

Log in with the existing account and encryption key using isolated test client
data directories. Confirm an existing history item decrypts, then synchronize
a harmless new marker between two test clients before restoring production
ingress. Preserve the pre-migration dump if upgrading afterward.

### Syncthing

Treat synchronized content and device identity separately. Keep networking or
the service disabled while restoring `~/.config/syncthing` and selected data.
Normally restore the original device certificate and key before reconnecting
peers; otherwise deliberately remove the old device and enroll a replacement.
Inspect folder paths, device IDs, and versioning first. Reconnect one trusted
peer, verify override/send-receive policy, then reconnect the rest. Do not let
an empty new device propagate deletions.

### Uptime Kuma

Kuma uses systemd `DynamicUser`; `/var/lib/uptime-kuma` is only a compatibility
symlink and the archived state is under `/var/lib/private/uptime-kuma`. Keep
Kuma stopped while copying that staged SQLite state to an empty actual state
directory. Let systemd re-establish the compatibility path and ownership when
starting it on loopback, verify monitor count and history, then send a
notification test. Do not infer recoverability merely because the SQLite file
opens.

### T3 Code

T3 Code's `/home/maxpw/.local/share/t3code` tree is primary state. The backup
pre-hook transforms it into `/var/backup/t3code/state.tar` while T3 Code remains
online: SQLite's backup API creates a standalone `state.sqlite`, then the
identity, cloud-link/signing keys, attachments, logs, caches, and managed
worktrees are copied around it. The live tree and transient SQLite WAL/SHM files
are excluded from Borg.

Keep `t3code.service` stopped in `maxpw`'s user manager during recovery. Extract
`var/backup/t3code/state.tar` into an empty staging directory, verify its
contents, then install that complete tree at `/home/maxpw/.local/share/t3code`
while preserving ownership and restrictive key-file modes. Never mix the
snapshot database, identity, keys, attachments, or worktrees from different
recovery points.

Use the package version recorded at `applicationVersions.t3code` in the archive
manifest first. If a newer package must migrate the database, retain the staged
pre-migration tree until acceptance succeeds. With the service still stopped,
run `sqlite3 /home/maxpw/.local/share/t3code/userdata/state.sqlite 'PRAGMA
integrity_check;'` and require the single result `ok`. Then start the service,
open the UI through isolated tailnet ingress, verify existing workspaces and
attachments, open an existing worktree, and create one new authenticated
workspace. A rollback requires restoring the complete pre-migration tree with
its matching package version.

### Leerr

Keep `leerr.service` stopped and restore the complete staged `/var/lib/leerr`
tree with the archived package version (the `leerr` input in the archived
`flake.lock`) and its matching encryption key. Preserve owner `leerr:leerr`,
directory mode 0700, file permissions and SQLite sidecar files. Test SQLite
integrity, account login and per-user Jellyfin library access in an isolated
instance; do not expose the service before they pass. A generation rollback
does not undo a SQLite migration: restore the matching pre-upgrade database if
the older application cannot read the new schema.

### Grafana and Prometheus

Their local databases/TSDB are intentionally disposable. Rebuild Grafana's
provisioned datasource and dashboard and allow Prometheus to start with empty
history. Confirm the Kim dashboard, datasource, roles, alert rules, and backup
freshness panels exist. Grafana's generated secret key is intentionally not a
portable credential; integrations that later depend on it must become
provisioned or the key must be reclassified as required state.

## Storage identities

Kernel names such as `/dev/nvme0n1` and `sdb2` change across reboots and
reconnects; never infer a role from them. Before touching any device, capture
the live layout and compare serials physically:

```sh
sudo lsblk -o NAME,PATH,MODEL,SERIAL,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINTS
sudo blkid
ls -l /dev/disk/by-id /dev/disk/by-uuid
```

| Role | Live identifier | Hardware identity (verify live) | Notes |
| --- | --- | --- | --- |
| root | UUID `b7617fb1-d251-481a-9395-d17bbc9d0c1f` | `nvme-CT1000P3PSSD8_25144F70A197` | ext4 |
| `/srv` | label `storage` | `nvme-CT1000P3PSSD8_25164F85F83A` | ext4; primary media and service state |
| local backup | UUID `73afcc5c-6148-4dc2-ae0e-61649ce71120` | `ata-TOSHIBA_MQ04UBF100_35PPP14JT` | ext4; Borg repository at `/mnt/backups` |
| LaCie media | UUID `4139bef6-d76c-4c41-99f6-3fd6090bdcd1`, label `media-secondary` | `ata-ST5000LM000-2AN170_WCJ23AWJ-part2` | ext4 at `/srv/media-secondary`, `nofail`; not in Borg |

`machines/hardware/kim-disko.nix` is not imported and erases its target. Run it
only against a blank replacement disk whose by-id you have just verified, never
against a mounted or listed disk. Update this table and the monitoring device
arguments together, from live output only.

## 6. Validate before ingress

Run the read-only smoke check and application acceptance checks while ingress is
still masked:

```sh
sudo homelab-check
systemctl --failed
```

The default check does not inspect Borg or attach an inactive backup automount.
Run `sudo env HOMELAB_CHECK_ARCHIVE=1 homelab-check` only when repository member
inspection is intended and attaching `/mnt/backups` is acceptable.

Verify loopback listeners, PostgreSQL socket-only operation, `/srv` backing
storage, Tailscale named-service expectations, Cloudflare unit state,
Prometheus targets, and backup/check age. Test intended and unauthorized access
before unmasking Cloudflare or Tailscale Serve.

Generate new tokens that portable exports intentionally omit. Do not rotate
Vaultwarden RSA or Syncthing device identity accidentally.

## 7. Finish and destroy staged plaintext

Record counts, checks, failures, corrective actions, and total recovery time.
For a real recovery, create a fresh backup from the recovered host and inspect
it before retiring old media. Keep old disks and repositories untouched until
application-level acceptance passes.

After the drill record is safely stored outside Kim:

```sh
sudo rm -rf /var/tmp/homelab-state /var/tmp/homelab-manifest \
  /var/tmp/homelab-restore /var/tmp/home-assistant-config
```

Quarterly completion requires successful Paperless import, isolated PostgreSQL
restore, Home Assistant config/recorder load, Immich database/storage integrity
and a mobile upload, media-stack control-state restoration plus playback and
transcoding, representative Nextcloud files and calendar data, Vaultwarden
items and attachments, a Uptime Kuma notification test, and T3 Code workspace,
attachment, identity, and worktree validation.
