{config, ...}: let
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
        "homelab.maximilian.pw" = {
          service = "http://127.0.0.1:8082";
          originRequest.httpHostHeader = "homelab.maximilian.pw";
        };
        "nextcloud.maximilian.pw" = {
          service = "http://127.0.0.1:8080";
          originRequest.httpHostHeader = "nextcloud.maximilian.pw";
        };
        "homeassistant.maximilian.pw" = {
          service = "http://127.0.0.1:8123";
          originRequest.httpHostHeader = "homeassistant.maximilian.pw";
        };
        "kuma.maximilian.pw" = {
          service = "http://127.0.0.1:3001";
          originRequest.httpHostHeader = "kuma.maximilian.pw";
        };
        "paperless.maximilian.pw" = {
          service = "http://127.0.0.1:28981";
          originRequest.httpHostHeader = "paperless.maximilian.pw";
        };
        "miniflux.maximilian.pw" = {
          service = "http://127.0.0.1:3002";
          originRequest.httpHostHeader = "miniflux.maximilian.pw";
        };
        "syncthing.maximilian.pw" = {
          service = "http://127.0.0.1:8384";
          originRequest.httpHostHeader = "syncthing.maximilian.pw";
        };
        "t3code.maximilian.pw" = {
          service = "http://127.0.0.1:51000";
          originRequest.httpHostHeader = "t3code.maximilian.pw";
        };
      };
    };
  };
}
