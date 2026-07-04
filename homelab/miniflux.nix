{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) miniflux;
in {
  sops.secrets.miniflux-admin-credentials = {
    restartUnits = ["miniflux.service"];
  };

  services.miniflux = {
    enable = true;
    createDatabaseLocally = true;
    adminCredentialsFile = config.sops.secrets.miniflux-admin-credentials.path;
    config = {
      LISTEN_ADDR = "127.0.0.1:${toString miniflux.port}";
      BASE_URL = miniflux.url;
    };
  };
}
