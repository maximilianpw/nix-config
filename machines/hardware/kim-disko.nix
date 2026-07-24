# Declarative root-disk layout for kim (Beelink SER9).
# The device is pinned by serial because Linux currently assigns the root disk
# as nvme1n1 and the /srv storage disk as nvme0n1. Using the kernel name here
# would erase the storage disk during reprovisioning.
# NOT imported into the live config — the hardware/kim.nix UUID-based mounts remain in use.
#
# Review this file against `lsblk` and inspect the locked plan first:
#   nix run .#disko -- --dry-run --mode disko ./machines/hardware/kim-disko.nix
# The same command without `--dry-run` is destructive. Never substitute a
# /dev/nvmeXnY kernel name for the pinned device below.
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/disk/by-id/nvme-CT1000P3PSSD8_25144F70A197";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0077" "dmask=0077"];
            };
          };
          swap = {
            # Created last so the root partition remains p2, matching the live
            # layout. It consumes the final 64 GiB reserved by root.end.
            priority = 3000;
            size = "100%";
            content = {
              type = "swap";
            };
          };
          root = {
            priority = 2000;
            size = "0";
            end = "-64G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
