{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  public = homelab.publicEndpoints;
  inherit (homelab.infrastructure.cloudflare) tunnelId unit;
in {
  sops.secrets."cloudflared-creds.json" = {
    restartUnits = [unit];
  };

  services.cloudflared = {
    enable = true;

    tunnels.${tunnelId} = {
      credentialsFile = config.sops.secrets."cloudflared-creds.json".path;
      default = "http_status:404";

      ingress = lib.mapAttrs' (_: endpoint:
        lib.nameValuePair endpoint.host {
          service = homelab.loopbackUrl endpoint.port;
          originRequest.httpHostHeader = endpoint.host;
        })
      public;
    };
  };
}
