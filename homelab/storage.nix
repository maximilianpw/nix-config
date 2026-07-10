{lib, ...}: let
  srvConsumers = [
    "nextcloud-cron"
    "nextcloud-setup"
    "nextcloud-update-db"
    "nextcloud-update-plugins"
    "paperless-consumer"
    "paperless-exporter"
    "paperless-scheduler"
    "paperless-task-queue"
    "paperless-web"
    "phpfpm-nextcloud"
  ];
in {
  # Spare 1TB internal SSD (nvme0n1p2) repurposed as bulk storage for
  # self-hosted services. Mounted by filesystem label so it survives a
  # reformat without needing a config change.
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
    lib.genAttrs srvConsumers (_: {
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
