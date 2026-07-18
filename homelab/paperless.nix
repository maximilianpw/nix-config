{
  config,
  lib,
  pkgs,
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
    configureTika = true;
    passwordFile = config.sops.secrets.paperless-admin-password.path;
    settings = {
      PAPERLESS_ADMIN_USER = "admin";
      PAPERLESS_ALLOWED_HOSTS = homelab.allowedHosts paperless.host;
      PAPERLESS_CSRF_TRUSTED_ORIGINS = paperless.url;
      PAPERLESS_OCR_LANGUAGE = "eng+fra";
      # Keep bulk OCR responsive without letting it occupy all 24 logical CPUs
      # on a host shared with the rest of the homelab.
      PAPERLESS_TASK_WORKERS = 2;
      PAPERLESS_THREADS_PER_WORKER = 1;
    };
    exporter = {
      enable = true;
      # Borg starts the exporter synchronously while applications are quiesced,
      # so its supported restore format is part of each archive.
      onCalendar = null;
    };
  };

  systemd.services = {
    paperless-exporter = {
      # The upstream unit defaults to Type=simple, so `systemctl start` returns
      # before document_exporter finishes. Borg requires completion semantics.
      serviceConfig.Type = "oneshot";
      # The Borg hook records and restores the exact pre-backup service set.
      # Do not let the exporter independently start every Paperless unit.
      unitConfig = {
        OnFailure = lib.mkForce [];
        OnSuccess = lib.mkForce [];
      };
    };

    # The NixOS module records the bootstrap credentials here. Paperless has
    # already applied them when ExecStartPost runs, so do not persist plaintext.
    paperless-scheduler.serviceConfig.ExecStartPost = "${lib.getExe' pkgs.coreutils "rm"} -f /srv/paperless/superuser-state";
  };
}
