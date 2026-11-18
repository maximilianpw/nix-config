{
  config,
  homelab,
  inputs,
  lib,
  pkgs,
  ...
}: let
  endpoint = homelab.publicEndpoints.cliproxy;
  # Guests may call /v1/ but not the owner-only quota endpoint. Removing a
  # name revokes its key once Kim is rebuilt.
  guests = ["guest"];
  guestKeySecret = name: "cliproxyapi-guest-api-key-${name}";
  cliProxy = import ../modules/cliproxyapi/config.nix;
  managementLocation = {
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
in {
  services.cliproxyapi-quota.history = {
    prometheusUrl = homelab.loopbackUrl homelab.services.prometheus.endpoint.port;
    managementUrl = cliProxy.baseUrl;
  };

  sops = {
    secrets =
      {cliproxyapi-public-api-key = {};}
      // lib.genAttrs (map guestKeySecret guests) (_: {});
    templates = {
      "cliproxyapi-public-auth.conf" = {
        owner = config.services.nginx.user;
        mode = "0400";
        restartUnits = ["nginx.service"];
        content = let
          client = secret: name: ''"~^Bearer ${config.sops.placeholder.${secret}}$" ${name};'';
          clients =
            [(client "cliproxyapi-public-api-key" "owner")]
            ++ map (name: client (guestKeySecret name) "guest-${name}") guests;
        in ''
          map $http_authorization $cliproxyapi_client {
            default "";
            ${lib.concatStringsSep "\n  " clients}
          }
        '';
      };
      "cliproxyapi-upstream-auth.conf" = {
        owner = config.services.nginx.user;
        mode = "0400";
        restartUnits = ["nginx.service"];
        content = ''
          proxy_set_header Authorization "Bearer ${config.sops.placeholder.cliproxyapi-local-api-key}";
        '';
      };
    };
  };

  services.nginx = {
    enable = true;
    # The build-time gixy validator cannot resolve SOPS templates rendered under
    # /run. nginx still validates the complete configuration in ExecStartPre.
    validateConfigFile = false;
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
        "= /healthz".return = "204";
        "= /management.html" = {
          alias = "${inputs.fleet.packages.${pkgs.stdenv.hostPlatform.system}.cliproxy-ui}/share/cliproxy-ui/management.html";
          extraConfig = ''
            add_header Cache-Control "no-store" always;
          '';
        };
        "/v0/management/" = managementLocation;
        "/v8/management/" = managementLocation;
        "/v8/management/observability/quota/" = {
          proxyPass = "${cliProxy.quotaBaseUrl}/observability/quota/";
          extraConfig = ''
            add_header Cache-Control "no-store" always;
          '';
        };
        "/quota/v1/" = {
          proxyPass = cliProxy.quotaBaseUrl;
          extraConfig = ''
            if ($cliproxyapi_client != owner) { return 401; }
            proxy_set_header Authorization "";
            add_header Cache-Control "no-store" always;
          '';
        };
        "/v1/" = {
          proxyPass = cliProxy.baseUrl;
          proxyWebsockets = true;
          extraConfig = ''
            if ($cliproxyapi_client = "") { return 401; }
            include ${config.sops.templates."cliproxyapi-upstream-auth.conf".path};
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
