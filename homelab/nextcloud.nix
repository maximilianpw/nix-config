{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.publicEndpoints) nextcloud;
in {
  sops.secrets.nextcloud-admin-password = {};

  services.nextcloud = {
    enable = true;
    package = pkgs.nextcloud33;
    hostName = "nextcloud.maximilian.pw";

    # Whole instance (config, data, store-apps) lives on the storage SSD.
    home = "/srv/nextcloud";

    # Cloudflare terminates TLS at the edge; generate https URLs regardless.
    https = true;

    autoUpdateApps.enable = true;
    # Keep existing app-store apps available alongside the immutable packaged
    # Paperless integration.
    appstoreEnable = true;
    extraApps.integration_paperless =
      pkgs.nextcloud33Packages.apps.integration_paperless;
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
      trusted_proxies = ["127.0.0.1" "::1"];
      trusted_domains = ["nextcloud.maximilian.pw"];
      overwriteprotocol = "https";
      overwritehost = "nextcloud.maximilian.pw";
      "overwrite.cli.url" = "https://nextcloud.maximilian.pw";
      default_phone_region = "FR";
      maintenance_window_start = 4;
    };

    phpOptions = {
      "opcache.interned_strings_buffer" = "16";
      "opcache.memory_consumption" = "256";
    };
  };

  # Serve only on localhost for the Cloudflare tunnel (TLS terminates at the edge).
  services.nginx.virtualHosts."nextcloud.maximilian.pw".listen = [
    {
      addr = "127.0.0.1";
      inherit (nextcloud) port;
    }
  ];
}
