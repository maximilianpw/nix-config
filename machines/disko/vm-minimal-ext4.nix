{lib, ...}: {
  # Matches labels used by hardware profiles: boot (FAT32) + nixos-root (ext4)
  disko.devices = {
    # VMware Fusion/Workstation on Apple Silicon typically exposes NVMe as /dev/nvme0n1
    # If your controller is SCSI, change the device to /dev/sda and the key to disk.sda
    disk.nvme0n1 = {
      type = "disk";
      device = "/dev/nvme0n1";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            priority = 1;
            size = "512MiB";
            type = "ef00"; # EFI System Partition
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = ["fmask=0022" "dmask=0022" "utf8=1"];
              extraArgs = ["-n" "boot"]; # set label
            };
          };

          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              extraArgs = ["-L" "nixos-root"];
            };
          };
        };
      };
    };
  };
}
