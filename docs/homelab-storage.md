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
| `/srv` | label `storage` | **Record from live audit before changing the mount** | ext4 | Label is retained for compatibility; migrate to the verified unique UUID separately |
| local backup | UUID `73afcc5c-6148-4dc2-ae0e-61649ce71120` | **Record model/serial from live audit** | ext4 | Removable Borg repository at `/mnt/backups` |

Do not infer a role from an NVMe namespace number. Update the table only from
live output, and review monitoring device arguments in the same change.

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
