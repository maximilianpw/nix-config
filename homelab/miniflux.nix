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
    # Miniflux stores per-user preferences in PostgreSQL. The canonical copy of
    # the custom stylesheet applied to the admin account is kept beside this
    # module in ./miniflux-theme.css.
    config = {
      LISTEN_ADDR = "127.0.0.1:${toString miniflux.port}";
      BASE_URL = miniflux.url;
    };
  };
}
