{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = (homelab.endpoints config.homelab.tailnet.domain).immich;
  immich = config.services.immich;
  server = config.systemd.services.immich-server;
in
  assert lib.assertMsg immich.enable
  "Immich must remain enabled on Kim";
  assert lib.assertMsg (
    immich.host
    == "127.0.0.1"
    && immich.port == endpoint.port
    && !immich.openFirewall
  )
  "Immich must be reachable only through its declared loopback backend";
  assert lib.assertMsg (
    immich.mediaLocation
    == "/srv/immich"
    && immich.database.enable
    && immich.redis.enable
    && immich.machine-learning.enable
  )
  "Immich must use persistent media storage with its local database, cache, and ML service";
  assert lib.assertMsg (immich.settings.server.externalDomain == endpoint.url)
  "Immich must generate links for its private HTTPS endpoint";
  assert lib.assertMsg (
    immich.accelerationDevices
    == ["/dev/dri/renderD128"]
    && immich.settings.ffmpeg.accel == "vaapi"
    && immich.settings.ffmpeg.accelDecode
    && server.serviceConfig.DeviceAllow == ["/dev/dri/renderD128"]
    && !server.serviceConfig.PrivateDevices
    && builtins.elem "render" config.users.users.immich.extraGroups
  )
  "Immich must offload video encoding and decoding to Kim's VA-API device";
  assert lib.assertMsg (
    builtins.elem "srv.mount" server.requires
    && builtins.elem "srv.mount" server.after
    && builtins.elem "/srv" server.unitConfig.RequiresMountsFor
  )
  "Immich must fail closed instead of writing media to the root disk when /srv is absent";
  assert lib.assertMsg (builtins.elem "d /srv/immich 0700 immich immich -" config.systemd.tmpfiles.rules)
  "Immich's non-default media directory must be created with private ownership";
    pkgs.runCommand "immich-config-regression" {} ''
      touch "$out"
    ''
