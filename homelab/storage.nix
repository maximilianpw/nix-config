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
