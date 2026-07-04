{config, ...}: let
  paperlessHost = "paperless.${config.homelab.tailnet.domain}";
  paperlessUrl = "https://${paperlessHost}";
in {
  sops.secrets.paperless-admin-password = {
    restartUnits = ["paperless-scheduler.service"];
  };

  services.paperless = {
    enable = true;
    address = "127.0.0.1";
    port = 28981;
    domain = paperlessHost;

    # Document storage lives on the storage SSD (DB stays on the root disk).
    dataDir = "/srv/paperless";
    mediaDir = "/srv/paperless/media";
    consumptionDir = "/srv/paperless/consume";

    database.createLocally = true;
    passwordFile = config.sops.secrets.paperless-admin-password.path;
    settings = {
      PAPERLESS_ADMIN_USER = "admin";
      PAPERLESS_ALLOWED_HOSTS = "${paperlessHost},localhost,127.0.0.1";
      PAPERLESS_CSRF_TRUSTED_ORIGINS = paperlessUrl;
      PAPERLESS_OCR_LANGUAGE = "eng+fra";
    };
    exporter = {
      enable = true;
      onCalendar = "03:30:00";
    };
  };
}
