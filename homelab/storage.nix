{lib, ...}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
in {
  # Existing bulk-storage filesystem for self-hosted services. Kernel NVMe
  # names are not stable identities; docs/homelab-storage.md records the live
  # audit needed before migrating this compatibility label to a unique UUID.
  fileSystems."/srv" = {
    device = "/dev/disk/by-label/storage";
    fsType = "ext4";
    # Mount before tmpfiles/service setup so units whose state lives on /srv
    # (e.g. Nextcloud's tmpfiles-managed override.config.php symlink) don't get
    # written to the hidden root /srv during early boot.
    options = [
      "x-systemd.before=systemd-tmpfiles-setup.service"
      "x-systemd.device-timeout=30s"
    ];
  };

  # LaCie USB disk for new finished downloads and library titles. Keep its
  # hardware identity pinned; the partition must be ext4 before activation.
  # nofail keeps boot and existing /srv media playback working without it; the
  # downloaders require it and stay stopped instead.
  fileSystems."/srv/media-secondary" = {
    device = "/dev/disk/by-id/ata-ST5000LM000-2AN170_WCJ23AWJ-part2";
    fsType = "ext4";
    # noauto: without it, systemd remounts the disk whenever its device
    # re-announces itself, including right after an unmount, so it could not be
    # unplugged safely. The downloaders and media-secondary-directories pull it
    # in through RequiresMountsFor instead.
    options = [
      "noauto"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # The LaCie Rugged USB-C bridge stalled and needed UAS resets during
  # sustained writes. Plain usb-storage is slower than UAS but the SMR disk
  # is the bottleneck anyway. Takes effect after a reboot or re-plug.
  boot.kernelParams = ["usb-storage.quirks=059f:1093:u"];

  # With 60 GB of RAM the default writeback limit let ~9 GB of "moved" media
  # sit in memory after Sonarr had deleted the originals. Cap it so copies run
  # at disk speed and a USB drop loses at most 256 MiB.
  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_SERIAL}=="ST5000LM000-2AN170_WCJ23AWJ", ATTR{bdi/strict_limit}="1", ATTR{bdi/max_bytes}="268435456"
  '';

  # Do not let stateful services silently use the root filesystem when the
  # storage SSD is absent or failed. RequiresMountsFor also follows the path if
  # the mount layout changes later.
  systemd.services =
    lib.genAttrs homelab.srvConsumers (_: {
      requires = ["srv.mount"];
      after = ["srv.mount"];
      unitConfig.RequiresMountsFor = ["/srv"];
    })
    // {
      systemd-tmpfiles-setup = {
        requires = ["srv.mount"];
        after = ["srv.mount"];
      };
    };
}
