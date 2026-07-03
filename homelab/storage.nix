_: {
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
      "nofail"
      "x-systemd.before=systemd-tmpfiles-setup.service"
    ];
  };
}
