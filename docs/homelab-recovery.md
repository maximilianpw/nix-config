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
  home-assistant.service nextcloud-cron.service nextcloud-cron.timer \
  nextcloud-setup.service nextcloud-update-db.service \
  nextcloud-update-store-apps.service nextcloud-update-store-apps.timer \
  phpfpm-nextcloud.service paperless-consumer.service \
  paperless-exporter.service paperless-scheduler.service \
  paperless-task-queue.service paperless-web.service miniflux.service \
  immich-machine-learning.service immich-server.service \
  bazarr.service jellyfin.service lidarr.service prowlarr.service \
  radarr.service seerr.service sonarr.service \
  container@qbt.service container@sab.service \
  qbittorrent-proxy.service qbittorrent-proxy.socket \
  sabnzbd-proxy.service sabnzbd-proxy.socket \
  syncthing.service uptime-kuma.service vaultwarden.service
```

Also keep `t3code.service` stopped in `maxpw`'s user manager while restoring its
state.

Use separate ports, databases, DNS, and Tailscale identity for a drill. Never
expose a drill instance through production ingress.

## 3. Stage the complete recovery point

Create a second empty directory and extract the required members. Never point
`borg-restore-main` at `/`, `/srv`, `/var/lib`, or any live service path.

```sh
sudo install -d -m 0700 /var/tmp/homelab-state
sudo borg-restore-main <archive> /var/tmp/homelab-state \
  var/backup/homelab/manifest.json \
  var/backup/home-assistant/config.tar var/backup/postgresql \
  srv/immich srv/nextcloud srv/paperless/export srv/paperless/consume \
  srv/paperless/media var/lib/bazarr var/lib/bitwarden_rs var/lib/jellyfin \
  var/lib/lidarr/.config/Lidarr var/lib/nixos-containers/qbt \
  var/lib/nixos-containers/sab \
  var/lib/private/jellyseerr var/lib/private/prowlarr \
  var/lib/private/uptime-kuma var/lib/radarr/.config/Radarr \
  var/lib/sabnzbd var/lib/sonarr/.config/NzbDrone \
  home/maxpw/.config/syncthing home/maxpw/.local/share/t3code \
  home/maxpw/Sync
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
Confirm that `hass`, `immich`, `miniflux`, `nextcloud`, `paperless`, and
`vaultwarden` exist with their expected owners. Restore files before starting
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

1. Keep Jellyfin, Sonarr, Radarr, Lidarr, Bazarr, Prowlarr, Seerr, both
   downloader containers, and both host proxies stopped. Restore each staged
   control-state path into an explicitly created empty destination, preserving
   numeric ownership.
2. Downloaded files under `/srv/media` are not in the Borg archive. Restore
   them from their separate copy if one exists; otherwise leave the media tree
   empty and reconcile missing entries after the control plane is healthy.
3. Start `container@qbt` and `container@sab`. In both namespaces confirm
   Mullvad is connected and `wg0-mullvad` exists. Confirm qBittorrent is bound
   to that interface and SABnzbd passed its VPN connection gate before
   unmasking `qbittorrent-proxy.socket` and `sabnzbd-proxy.socket`.
4. Start Prowlarr, Sonarr, Radarr, Lidarr, Bazarr, Jellyfin, and Seerr with the
   package versions recorded in the manifest. Before resuming SABnzbd's queue,
   confirm every restored provider uses port 563, SSL, and strict certificate
   verification. Validate application connections, root folders, categories,
   history, users, libraries, and watch state.
5. Run the end-to-end checks in [the media-stack runbook](media-stack.md#acceptance-checks),
   including a hardlink import when media is available and both direct-play and
   VA-API transcoding. Retain the staged trees until all checks pass.

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

### Miniflux

Restore the `miniflux` database, start the archived package on loopback, log in,
open representative feeds, refresh one feed, and verify read/starred state and
custom preferences.

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

T3 Code's `/home/maxpw/.local/share/t3code` tree is primary state. It contains
the SQLite database and WAL, attachments, identity and cloud-link/signing key
material, and managed worktrees. Keep `t3code.service` stopped in `maxpw`'s user
manager and restore that complete tree from one archive, preserving ownership
and restrictive key-file modes. Never mix its database, WAL, identity, keys,
attachments, or worktrees from different recovery points.

Use the package version recorded at `applicationVersions.t3code` in the archive
manifest first. If a newer package must migrate the database, retain the staged
pre-migration tree until acceptance succeeds. With the service still stopped,
run `sqlite3 /home/maxpw/.local/share/t3code/userdata/state.sqlite 'PRAGMA
integrity_check;'` and require the single result `ok`. Then start the service,
open the UI through isolated tailnet ingress, verify existing workspaces and
attachments, open an existing worktree, and create one new authenticated
workspace. A rollback requires restoring the complete pre-migration tree with
its matching package version.

### Grafana and Prometheus

Their local databases/TSDB are intentionally disposable. Rebuild Grafana's
provisioned datasource and dashboard and allow Prometheus to start with empty
history. Confirm the Kim dashboard, datasource, roles, alert rules, and backup
freshness panels exist. Grafana's generated secret key is intentionally not a
portable credential; integrations that later depend on it must become
provisioned or the key must be reclassified as required state.

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
sudo rm -rf /var/tmp/homelab-state \
  /var/tmp/homelab-restore /var/tmp/home-assistant-config
```

Quarterly completion requires successful Paperless import, isolated PostgreSQL
restore, Home Assistant config/recorder load, Immich database/storage integrity
and a mobile upload, media-stack control-state restoration plus playback and
transcoding, representative Nextcloud files and calendar data, Vaultwarden
items and attachments, a Uptime Kuma notification test, and T3 Code workspace,
attachment, identity, and worktree validation.
