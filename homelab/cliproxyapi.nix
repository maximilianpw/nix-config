{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = homelab.publicEndpoints.cliproxy;
  cliProxy = import ../modules/cliproxyapi/config.nix;
in {
  sops = {
    secrets.cliproxyapi-public-api-key = {};
    templates."cliproxyapi-public-auth.conf" = {
      owner = config.services.nginx.user;
      mode = "0400";
      restartUnits = ["nginx.service"];
      content = ''
        map $http_authorization $cliproxyapi_public_authorized {
          default 0;
          "~^Bearer ${config.sops.placeholder.cliproxyapi-public-api-key}$" 1;
        }
      '';
    };
  };

  services.nginx = {
    enable = true;
    appendHttpConfig = ''
      include ${config.sops.templates."cliproxyapi-public-auth.conf".path};
    '';
    virtualHosts.${endpoint.host} = {
      listen = [
        {
          addr = "127.0.0.1";
          inherit (endpoint) port;
        }
      ];
      locations = {
        "/" = {
          return = "302 /management.html";
          extraConfig = ''
            absolute_redirect off;
          '';
        };
        "= /management.html" = {
          proxyPass = cliProxy.baseUrl;
          extraConfig = ''
            add_header Cache-Control "no-store" always;
          '';
        };
        "/v0/management/" = {
          proxyPass = cliProxy.baseUrl;
          proxyWebsockets = true;
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
            client_max_body_size 100m;
            add_header Cache-Control "no-store" always;
          '';
        };
        "/v1/" = {
          proxyPass = cliProxy.baseUrl;
          proxyWebsockets = true;
          extraConfig = ''
            if ($cliproxyapi_public_authorized = 0) { return 401; }
            proxy_set_header Authorization "Bearer ${cliProxy.apiKey}";
            proxy_buffering off;
            proxy_request_buffering off;
            proxy_read_timeout 600s;
            proxy_send_timeout 600s;
            client_max_body_size 100m;
          '';
        };
      };
    };
  };
}
