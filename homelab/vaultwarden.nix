{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) vaultwarden;
in {
  sops.secrets.vaultwarden-environment = {
    restartUnits = ["vaultwarden.service"];
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    configurePostgres = true;
    domain = vaultwarden.host;
    environmentFile = config.sops.secrets.vaultwarden-environment.path;

    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = vaultwarden.port;
      ENABLE_WEBSOCKET = true;
      SIGNUPS_ALLOWED = false;
      SHOW_PASSWORD_HINT = false;
    };
  };
}
