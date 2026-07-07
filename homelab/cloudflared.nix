{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  public = homelab.publicEndpoints;
  tunnelId = "5b712ae4-3ce4-4499-9cb7-a57cde1c571f";
in {
  sops.secrets."cloudflared-creds.json" = {
    restartUnits = ["cloudflared-tunnel-${tunnelId}.service"];
  };

  services.cloudflared = {
    enable = true;

    tunnels.${tunnelId} = {
      credentialsFile = config.sops.secrets."cloudflared-creds.json".path;
      default = "http_status:404";

      ingress = {
        ${public.nextcloud.host} = {
          service = homelab.loopbackUrl public.nextcloud.port;
          originRequest.httpHostHeader = public.nextcloud.host;
        };
        ${public.homeassistant.host} = {
          service = homelab.loopbackUrl public.homeassistant.port;
          originRequest.httpHostHeader = public.homeassistant.host;
        };
      };
    };
  };
}
