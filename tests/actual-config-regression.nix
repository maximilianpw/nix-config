{
  config,
  expectedPackage,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = homelab.publicEndpoints.actual;
  tunnel = config.services.cloudflared.tunnels.${homelab.infrastructure.cloudflare.tunnelId};
  actual = config.services.actual;
in
  assert lib.assertMsg (
    homelab.services.actual.endpoint.exposure
    == "public"
    && homelab.services.actual.endpoint.authorizationOwner == "application"
    && endpoint.url == "https://actual.maximilian.pw"
    && !(homelab.privateServices ? actual)
    && tunnel.ingress.${endpoint.host}.service == homelab.loopbackUrl endpoint.port
    && tunnel.ingress.${endpoint.host}.originRequest.httpHostHeader == endpoint.host
    && !(builtins.elem endpoint.port config.networking.firewall.allowedTCPPorts)
  )
  "Actual Budget must use Cloudflare HTTPS with application authentication, no tailnet service and no public backend port";
  assert lib.assertMsg actual.enable
  "Actual Budget must be enabled";
  assert lib.assertMsg (actual.package == expectedPackage)
  "Actual Budget must track the nixpkgs-unstable package updated by the flake workflow";
  assert lib.assertMsg (!actual.openFirewall)
  "Actual Budget must not open a host firewall port";
  assert lib.assertMsg (
    actual.settings.hostname
    == "127.0.0.1"
    && actual.settings.port == endpoint.port
  )
  "Actual Budget must bind only its declared loopback endpoint";
  assert lib.assertMsg (
    actual.settings.loginMethod
    == "password"
    && actual.settings.allowedLoginMethods == ["password"]
  )
  "Actual Budget must only accept its password authentication method";
  assert lib.assertMsg (
    builtins.elem "actual.service" homelab.backup.archiveUnits
    && builtins.elem "/var/lib/actual" config.custom.backup.manifestMetadata.expectedPrimaryStatePaths
    && builtins.elem "/var/lib/actual" config.custom.backup.manifestMetadata.expectedArchivePaths
  )
  "Actual Budget state must be quiesced and archived";
    pkgs.runCommand "actual-config-regression" {} ''
      touch "$out"
    ''
