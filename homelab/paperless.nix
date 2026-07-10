{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) paperless;
in {
  sops.secrets.paperless-admin-password = {
    restartUnits = ["paperless-scheduler.service"];
  };

  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    inherit (paperless) port;
    domain = paperless.host;

    # Document storage lives on the storage SSD (DB stays on the root disk).
    dataDir = "/srv/paperless";
    mediaDir = "/srv/paperless/media";
    consumptionDir = "/srv/paperless/consume";

    database.createLocally = true;
    passwordFile = config.sops.secrets.paperless-admin-password.path;
    settings = {
      PAPERLESS_ADMIN_USER = "admin";
      PAPERLESS_ALLOWED_HOSTS = homelab.allowedHosts paperless.host;
      PAPERLESS_CSRF_TRUSTED_ORIGINS = paperless.url;
      PAPERLESS_OCR_LANGUAGE = "eng+fra";
    };
    exporter = {
      enable = true;
      # Borg starts the exporter synchronously before quiescing the remaining
      # applications, so its supported restore format is part of each archive.
      onCalendar = null;
    };
  };
}
