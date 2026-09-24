{
  config,
  lib,
  pkgs,
}: let
  expect = import ./lib/expect.nix {inherit lib;};
  homelab = import ../lib/homelab.nix {inherit lib;};
  tunnel = config.services.cloudflared.tunnels.${homelab.infrastructure.cloudflare.tunnelId};
  publicNames = builtins.attrNames homelab.publicEndpoints;
  publicHosts = map (name: homelab.publicEndpoints.${name}.host) publicNames;
  ingressHosts = builtins.attrNames tunnel.ingress;
  ingressIsLoopback = host: let
    ingress = tunnel.ingress.${host};
  in
    lib.hasPrefix "http://127.0.0.1:" ingress.service
    && ingress.originRequest.httpHostHeader == host;
  cliproxy = config.services.nginx.virtualHosts.${homelab.publicEndpoints.cliproxy.host};
  cliproxyPort = homelab.publicEndpoints.cliproxy.port;
  cliproxyBackend = (import ../modules/cliproxyapi/config.nix).baseUrl;
  nextcloudListen = config.services.nginx.virtualHosts.${homelab.publicEndpoints.nextcloud.host}.listen;
in
  assert lib.assertMsg (publicNames == ["cliproxy" "executor" "homeassistant" "jellyfin" "nextcloud" "plex" "seerr"])
  "Cloudflare ingress must expose the declared public application set";
  assert lib.assertMsg (ingressHosts == publicHosts)
  "Cloudflare ingress must derive exactly from the public service inventory";
  assert lib.assertMsg (lib.all ingressIsLoopback ingressHosts)
  "every public origin must use loopback and its exact public Host header";
  assert lib.assertMsg (tunnel.default == "http_status:404")
  "undeclared Cloudflare hostnames must reach the 404 fallback";
  assert lib.assertMsg (
    builtins.length nextcloudListen
    == 1
    && lib.all (listener:
      listener.addr
      == "127.0.0.1"
      && listener.port == homelab.publicEndpoints.nextcloud.port
      && !listener.ssl)
    nextcloudListen
  )
  "Nextcloud nginx must bind only its declared loopback origin";
  assert expect.all "CLIProxyAPI must expose its management UI behind the management key and protect its public API with a separate token" [
    (cliproxy.listen
      == [
        {
          addr = "127.0.0.1";
          port = cliproxyPort;
          ssl = false;
          proxyProtocol = false;
          extraParameters = [];
        }
      ])
    (cliproxy.locations."/".return == "302 /management.html")
    (lib.hasInfix "absolute_redirect off;" cliproxy.locations."/".extraConfig)
    (cliproxy.locations."= /healthz".return == "204")
    (cliproxy.locations."= /management.html".proxyPass == cliproxyBackend)
    (cliproxy.locations."/v0/management/".proxyPass == cliproxyBackend)
    (cliproxy.locations."/v1/".proxyPass == cliproxyBackend)
    (cliproxy.locations."/quota/v1/".proxyPass == "http://127.0.0.1:8318")
    (lib.hasInfix "if ($cliproxyapi_public_authorized = 0) { return 401; }" cliproxy.locations."/quota/v1/".extraConfig)
    (lib.hasInfix "proxy_set_header Authorization \"\";" cliproxy.locations."/quota/v1/".extraConfig)
    (config.systemd.services.cliproxyapi-quota.serviceConfig.User == config.systemd.services.cliproxyapi.serviceConfig.User)
    (lib.hasInfix "/pi-config/cli/cliproxyapi-quota-server.ts" config.systemd.services.cliproxyapi-quota.serviceConfig.ExecStart)
    (lib.hasInfix "if ($cliproxyapi_public_authorized = 0) { return 401; }" cliproxy.locations."/v1/".extraConfig)
    (lib.hasInfix config.sops.templates."cliproxyapi-upstream-auth.conf".path cliproxy.locations."/v1/".extraConfig)
    (lib.hasInfix "allow-remote: true" config.sops.templates."cliproxyapi.conf".content)
    (config.sops.templates."cliproxyapi-public-auth.conf".owner == config.services.nginx.user)
    (config.sops.templates."cliproxyapi-public-auth.conf".mode == "0400")
    (config.sops.templates."cliproxyapi-upstream-auth.conf".owner == config.services.nginx.user)
    (config.sops.templates."cliproxyapi-upstream-auth.conf".mode == "0400")
    (!(builtins.elem cliproxyPort config.networking.firewall.allowedTCPPorts))
  ];
  assert lib.assertMsg (
    lib.all (name: homelab.services.${name}.endpoint.authorizationOwner == "application") [
      "homeassistant"
      "jellyfin"
      "nextcloud"
      "plex"
      "seerr"
    ]
  )
  "public applications must declare application-owned authentication accurately";
  assert lib.assertMsg (config.services.home-assistant.config.http.server_host == "127.0.0.1")
  "Home Assistant must bind only its declared loopback origin";
  assert lib.assertMsg (config.services.nextcloud.settings.trusted_proxies == ["127.0.0.1" "::1"])
  "Nextcloud trusted proxies must remain loopback-only";
  assert lib.assertMsg (config.services.home-assistant.config.http.trusted_proxies == ["127.0.0.1" "::1"])
  "Home Assistant trusted proxies must remain loopback-only";
  assert expect.all "Leerr must use private HTTPS, loopback-only proxy trust, isolated state and a separate encryption key" [
    (homelab.services.leerr.endpoint.exposure == "tailnet")
    (config.systemd.services.leerr.environment.HOST == "127.0.0.1")
    (config.systemd.services.leerr.environment.LEERR_ORIGIN == "https://leerr.${homelab.tailnetDomain}")
    (config.systemd.services.leerr.environment.LEERR_TRUST_PROXY == "127.0.0.1")
    (config.systemd.services.leerr.serviceConfig.User == "leerr")
    (config.systemd.services.leerr.serviceConfig.StateDirectoryMode == "0700")
    (config.sops.secrets.leerr-encryption-key.owner == "leerr")
    (!(lib.hasPrefix "/var/lib/leerr/" config.systemd.services.leerr.environment.LEERR_KEY_FILE))
    (!(builtins.elem homelab.privateServices.leerr.port config.networking.firewall.allowedTCPPorts))
  ];
    pkgs.runCommand "homelab-ingress-regression" {} ''
      touch "$out"
    ''
