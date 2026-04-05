# Declarative disk layout for main-pc (Beelink SER9).
# This mirrors the existing partition scheme for documentation and reprovisioning.
# NOT imported into the live config — the hardware/main-pc.nix UUID-based mounts remain in use.
#
# To reprovision: nix run github:nix-community/disko -- --mode disko ./machines/hardware/main-pc-disko.nix
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/nvme0n1"; # Replace with /dev/disk/by-id/ path for stability
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0077" "dmask=0077"];
            };
          };
          swap = {
            size = "16G";
            content = {
              type = "swap";
            };
          };
          root = {
            size = "100%";
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
