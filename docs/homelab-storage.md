# Kim storage attachment and replacement

Live mounts and destructive provisioning are intentionally separate.
`machines/hardware/kim.nix` and `homelab/storage.nix` mount existing filesystems;
`machines/hardware/kim-disko.nix` is not imported and may erase only a reviewed
blank replacement target.

Kernel names such as `/dev/nvme0n1` are not identities and may change after a
firmware update or hardware move. Before changing this document or any device
reference, capture this table from Kim and compare serials physically:

```sh
sudo lsblk -o NAME,PATH,MODEL,SERIAL,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINTS
sudo blkid
ls -l /dev/disk/by-id /dev/disk/by-uuid
```

| Role | Live identifier | Stable hardware identity | Filesystem | Notes |
| --- | --- | --- | --- | --- |
| root | UUID `b7617fb1-d251-481a-9395-d17bbc9d0c1f` | Disko currently records `nvme-CT1000P3PSSD8_25144F70A197`; verify live | ext4 | Never run the Disko layout until this by-id is reverified |
| `/srv` | label `storage` | `nvme-CT1000P3PSSD8_25164F85F83A` (verify live) | ext4 | Primary media and service state; retained for compatibility |
| local backup | UUID `73afcc5c-6148-4dc2-ae0e-61649ce71120` | `ata-TOSHIBA_MQ04UBF100_35PPP14JT` (verify live) | ext4 | Removable Borg repository at `/mnt/backups` |
| LaCie media | `ata-ST5000LM000-2AN170_WCJ23AWJ-part2`; UUID `4139bef6-d76c-4c41-99f6-3fd6090bdcd1` | LaCie enclosure, SMR disk serial `WCJ23AWJ` (observed 2026-10-07; reverify before operations) | ext4, label `media-secondary` | `/srv/media-secondary`; new finished downloads and library; nofail, downloaders require it; not part of Borg |

Do not infer a role from an NVMe namespace number. Update the table only from
live output, and review monitoring device arguments in the same change.

## LaCie media disk

`homelab/storage.nix` pins partition 2 by hardware identity and expects
**ext4**. A read-only audit on **2026-10-07** confirmed that provisioning is
complete: partition 2 is mounted read-write at `/srv/media-secondary`, with
UUID `4139bef6-d76c-4c41-99f6-3fd6090bdcd1` and label `media-secondary`.
**Do not rerun the provisioning commands on the existing media disk.**

The disk is nominally 5 TB (about 4.5 TiB). At the audit it had approximately
717 GiB used and 3.6 TiB available. Kernel names changed from `sdb2` to `sdc2`
during last week's reconnect and are now `sdb2` again; use the stable by-id,
not those transient names.

### Reliability and monitoring observations

For September 28–October 4, 2026 (CEST):

- Prometheus's available-space utilization peaked at about 20.3%. There was
  one brief pending missing-mount alert during the September 29 reconnect;
  no missing-mount or capacity alert reached firing state.
- September 28 had UAS command aborts and a USB reset. The September 29
  disconnect logged lost sync-page writes and a JBD2 journal I/O error.
  After reconnect, the kernel reported that UAS was disabled in favor of
  `usb-storage`, matching the quirk in `homelab/storage.nix`.
- Read I/O errors with USB resets still occurred on October 1, October 2,
  and October 4 after that transport change. Mount availability and free
  space do **not** establish disk or transport health. The cause and any
  data-integrity impact remain unconfirmed; do not repair a mounted filesystem
  or run destructive tests as a diagnostic shortcut. Follow-up found more read
  errors on October 5 and a disconnect while mounted at 01:30, with a journal
  abort and lost writes before remount at 01:32. September 29 also remounted
  shortly before disconnect. These events were not clean unplugs; the logs do
  not establish whether cable removal or an electrical dropout caused them.
- At the audit, filesystem/missing-mount monitoring covered this drive, but
  the SMART exporter explicitly monitored only the two NVMe devices. Its
  healthy SMART readings therefore said nothing about the LaCie.
- Follow-up configuration changes add critical read-only/device-error alerts
  for the operational mounts, including this disk. They were verified loaded
  and healthy after the October 7 rebuild, with both fault gauges at 0.
  They cannot detect every short transport failure. SMART passthrough and
  persistent kernel-event monitoring remain unverified/follow-up work.

See [the weekly monitoring review](monitoring-review-2026-10-07.md) for the
related service incidents and follow-up priorities. Media is not covered by
Borg; preserve an independent copy before undertaking repair or replacement.

### Provisioning a replacement (destructive; not for the mounted disk)

The original partition was exFAT (UUID `9A66-BF3F`). The following historical
procedure is only a template for an explicitly approved, physically verified
blank replacement. Provisioning permanently erases the partition. Partition 1
is left untouched. Reconfirm the physical disk and every identifier, not just
`/dev/sdb`, and substitute the verified replacement's identity:

```sh
target=/dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ23AWJ-part2
lsblk -o NAME,PATH,MODEL,SERIAL,SIZE,FSTYPE,UUID,LABEL,MOUNTPOINTS
readlink -f "$target"
lsblk -dn -o MODEL,SERIAL /dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ23AWJ
findmnt -S "$target"    # must have no mount
# After physically verifying WCJ23AWJ, confirming no mount, and accepting data loss:
sudo wipefs -a "$target"
sudo mkfs.ext4 -L media-secondary "$target"
sudo blkid "$target"
```

### Cut over new downloads

Existing torrents, Usenet history, and library files are not moved by any step
below.

1. Build and activate the configuration. Check `findmnt /srv/media-secondary`
   resolves to the intended partition, `systemctl status
   media-secondary-directories.service` succeeded, and `container@qbt` and
   `container@sab` are running. SABnzbd now unpacks finished jobs to
   `/srv/media-secondary/usenet/complete`; jobs already in its history keep
   their old paths.
2. In qBittorrent, create the `*-lacie` categories from
   [media stack](media-stack.md#qbittorrent). Do not edit the existing
   categories or the default save path.
3. In each of Sonarr, Radarr, and Lidarr, **add** a second qBittorrent download
   client with the `*-lacie` category and a better (lower) priority than the
   existing qBittorrent client. Keep the existing client enabled so torrents
   already in flight still import; new grabs use the LaCie client.
4. Add the LaCie library roots, make them the default, and add them to
   Jellyfin and Plex as described in
   [media stack](media-stack.md#sonarr-radarr-and-lidarr).
5. Test one torrent and one NZB. Confirm the torrent's temporary pieces appear
   under `/srv/media/torrents/incomplete`, the finished file lands under
   `/srv/media-secondary/torrents`, and the library copy shares its inode:
   `stat -c '%d %i %h %n' <download> <library file>`.
6. After the 24-hour seeding limit has removed every torrent in the old
   categories, delete the old qBittorrent download client from each manager and
   the empty old categories from qBittorrent.

To unplug the LaCie, stop everything that reads it, confirm the mount is gone,
then power it down before pulling the cable:

```sh
sudo systemctl stop jellyfin plex tunarr 'srv-media\x2dsecondary.mount'
findmnt /srv/media-secondary    # must print nothing
echo 1 | sudo tee /sys/block/"$(basename "$(readlink -f /dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ23AWJ)")"/device/delete
sudo systemctl start jellyfin plex tunarr
```

After reconnecting, start it with
`sudo systemctl start 'srv-media\x2dsecondary.mount' container@qbt container@sab`.
The mount is `noauto`, so it does not remount itself when the device reappears.

If the LaCie is absent, the downloaders stay stopped and
`HomelabMediaSecondaryAbsent` alerts. Existing NVMe media keeps playing; titles
on the LaCie are unavailable until it is reattached. Media on either disk is
excluded from the Borg application-state backup; keep a separate copy of the
library if it matters.

## Attach an existing data disk without formatting

1. Stop and mask every `/srv` consumer. Confirm a recent local archive and an
   independently recoverable off-site archive.
2. Capture `lsblk`, `blkid`, by-id links, filesystem UUID, model, and serial.
3. Mount the filesystem read-only at a temporary path first:

   ```sh
   sudo install -d /mnt/storage-inspect
   sudo mount -o ro /dev/disk/by-uuid/<verified-uuid> /mnt/storage-inspect
   findmnt /mnt/storage-inspect
   sudo ls -la /mnt/storage-inspect
   sudo umount /mnt/storage-inspect
   ```

4. Compare the expected Nextcloud/Paperless trees and ownership. Do not run
   `mkfs`, Disko, partitioning, repair, or recursive ownership commands.
5. Change only the non-destructive `fileSystems."/srv".device` declaration to
   the verified unique UUID. Run `make lint` and `nix flake check --no-build`.
6. Mount `/srv`, run `findmnt /srv`, and confirm its source UUID before
   unmasking consumers. If the mount is absent, consumers must remain failed
   closed rather than writing to root.

## Provision a confirmed blank replacement disk

This workflow is destructive and is forbidden until the recovery runbook and
off-site extraction gates have passed.

1. Disconnect any disk that is not required. Physically disconnect at least one
   verified backup copy.
2. Capture the same live inventory and identify the blank replacement by its
   `/dev/disk/by-id/...` path. Cross-check model, serial, and capacity twice.
3. Copy the layout to a separately reviewed replacement file and edit that
   copy so only the blank disk's stable by-id appears. Never point this workflow
   at the canonical Kim root layout.
4. Bind the exact reviewed file and target once, mechanically compare the
   layout's evaluated target with the physically verified block device, then
   inspect that same file in dry-run mode:

   ```bash
   layout=./machines/hardware/kim-replacement-disko.nix
   target=/dev/disk/by-id/<verified-blank-device>
   declared=$(nix eval --impure --raw --expr \
     "(import (builtins.toPath \"$PWD/$layout\")).disko.devices.disk.main.device")
   [[ -b $target && $declared == "$target" ]] || {
     echo "reviewed layout and verified blank target do not match" >&2
     exit 1
   }
   rg 'device[[:space:]]*=' "$layout"
   nix run .#disko -- --dry-run "$layout"
   ```

5. Require a typed confirmation containing the complete stable path and invoke
   the **same** reviewed layout variable for the destructive command:

   ```bash
   read -r -p "Type the exact target ($target): " confirmation
   [[ $confirmation == "$target" ]] || { echo "aborted" >&2; exit 1; }
   sudo nix run .#disko -- --mode disko "$layout"
   ```

6. Rebuild the archived configuration revision first. Restore only from staging
   into empty paths with services disabled, then complete every acceptance
   check in `docs/homelab-recovery.md`.
7. Create and inspect a fresh archive from the replacement. Keep the old disk
   untouched until that archive and application-level recovery checks pass.

## Optional encryption or filesystem replacement

Do not combine attachment with LUKS, ext4 replacement, Btrfs/LVM conversion, or
bulk movement of `/srv`. Those require a separate migration plan, two verified
copies (one off-site), a frozen application window, and a tested rollback. A
filesystem is not safer merely because its layout can be declared in Nix.
