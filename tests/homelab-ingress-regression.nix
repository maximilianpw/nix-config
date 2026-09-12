{
  config,
  lib,
  pkgs,
}: let
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
  nextcloudListen = config.services.nginx.virtualHosts.${homelab.publicEndpoints.nextcloud.host}.listen;
  privatePorts = map (service: service.port) (builtins.attrValues homelab.privateServices);
in
  assert lib.assertMsg (publicNames == ["executor" "homeassistant" "jellyfin" "nextcloud" "seerr"])
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
  assert lib.assertMsg (config.services.home-assistant.config.http.server_host == "127.0.0.1")
  "Home Assistant must bind only its declared loopback origin";
  assert lib.assertMsg (config.services.nextcloud.settings.trusted_proxies == ["127.0.0.1" "::1"])
  "Nextcloud trusted proxies must remain loopback-only";
  assert lib.assertMsg (config.services.home-assistant.config.http.trusted_proxies == ["127.0.0.1" "::1"])
  "Home Assistant trusted proxies must remain loopback-only";
  assert lib.assertMsg (builtins.length privatePorts == builtins.length (lib.unique privatePorts))
  "tailnet backends must retain unique loopback ports";
  assert lib.assertMsg (
    homelab.services.leerr.endpoint.exposure
    == "tailnet"
    && config.systemd.services.leerr.environment.HOST == "127.0.0.1"
    && config.systemd.services.leerr.environment.LEERR_ORIGIN == "https://leerr.${config.homelab.tailnet.domain}"
    && config.systemd.services.leerr.environment.LEERR_TRUST_PROXY == "127.0.0.1"
    && config.systemd.services.leerr.serviceConfig.User == "leerr"
    && config.systemd.services.leerr.serviceConfig.StateDirectoryMode == "0700"
    && config.sops.secrets.leerr-encryption-key.owner == "leerr"
    && !(lib.hasPrefix "/var/lib/leerr/" config.systemd.services.leerr.environment.LEERR_KEY_FILE)
    && !(builtins.elem homelab.privateServices.leerr.port config.networking.firewall.allowedTCPPorts)
  )
  "Leerr must use private HTTPS, loopback-only proxy trust, isolated state and a separate encryption key";
    pkgs.runCommand "homelab-ingress-regression" {} ''
      touch "$out"
    ''
