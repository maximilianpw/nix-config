{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.publicEndpoints) nextcloud;
  declarativeAppIds = lib.attrNames config.services.nextcloud.extraApps;
  ownershipCheck = pkgs.writeShellApplication {
    name = "nextcloud-app-ownership-check";
    text = ''
      if (( $# == 0 )); then
        set -- ${lib.escapeShellArgs declarativeAppIds}
      fi
      exec ${lib.getExe pkgs.bash} ${../scripts/check-nextcloud-app-ownership.sh} "$@"
    '';
  };
  storeAppUpdater = pkgs.writeShellApplication {
    name = "nextcloud-update-store-apps";
    runtimeInputs = [pkgs.coreutils pkgs.findutils];
    text = ''
      export NEXTCLOUD_OWNERSHIP_CHECK_BIN=${lib.getExe ownershipCheck}
      export NEXTCLOUD_OCC_BIN=${lib.getExe config.services.nextcloud.occ}
      exec ${lib.getExe pkgs.bash} ${../scripts/update-nextcloud-store-apps.sh} ${lib.escapeShellArgs declarativeAppIds}
    '';
  };
in {
  sops.secrets.nextcloud-admin-password = {};

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud34;
    hostName = nextcloud.host;

    # Whole instance (config, data, store-apps) lives on the storage SSD.
    home = "/srv/nextcloud";

    # Cloudflare terminates TLS at the edge; generate https URLs regardless.
    https = true;

    # Packaged extraApps are immutable. `app:update --all` can copy an update
    # into store-apps, causing Nextcloud to load both versions of the same app.
    autoUpdateApps.enable = false;
    # Keep existing app-store apps available alongside immutable packaged apps.
    appstoreEnable = true;
    extraApps = {
      calendar = pkgs.nextcloud-calendar;
      integration_paperless =
        pkgs.nextcloud34Packages.apps.integration_paperless;
    };
    configureRedis = true;
    caching.redis = true;
    maxUploadSize = "16G";

    database.createLocally = true;
    config = {
      dbtype = "pgsql";
      adminuser = "admin";
      adminpassFile = config.sops.secrets.nextcloud-admin-password.path;
    };

    settings = {
      # The Paperless integration calls its tailnet-only endpoint server-side.
      allow_local_remote_servers = true;
      trusted_proxies = ["127.0.0.1" "::1"];
      trusted_domains = [nextcloud.host];
      overwriteprotocol = "https";
      overwritehost = nextcloud.host;
      "overwrite.cli.url" = nextcloud.url;
      default_phone_region = "FR";
      maintenance_window_start = 4;
    };

    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
      "opcache.memory_consumption" = "256";
    };
  };

  # Serve only on localhost for the Cloudflare tunnel (TLS terminates at the edge).
  services.nginx.virtualHosts.${nextcloud.host}.listen = [
    {
      addr = "127.0.0.1";
      inherit (nextcloud) port;
    }
  ];

  environment.systemPackages = [ownershipCheck storeAppUpdater];

  systemd.services.nextcloud-update-store-apps = {
    description = "Update mutable Nextcloud app-store apps";
    # homelab/storage.nix adds the shared /srv mount dependencies.
    after = ["nextcloud-setup.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "nextcloud";
      ExecStart = lib.getExe storeAppUpdater;
    };
  };

  systemd.timers.nextcloud-update-store-apps = {
    description = "Update mutable Nextcloud app-store apps daily";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "05:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
