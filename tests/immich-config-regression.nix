{
  config,
  lib,
  pkgs,
}: let
  expect = import ./lib/expect.nix {inherit lib;};
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoint = homelab.endpoints.immich;
  immich = config.services.immich;
  server = config.systemd.services.immich-server;
in
  assert lib.assertMsg immich.enable
  "Immich must remain enabled on Kim";
  assert lib.assertMsg (lib.versionAtLeast immich.package.version "3")
  "Immich must use the supported 3.x series rather than the insecure 2.x package from NixOS 26.05";
  assert lib.assertMsg (
    immich.host
    == "127.0.0.1"
    && immich.port == endpoint.port
    && !immich.openFirewall
  )
  "Immich must be reachable only through its declared loopback backend";
  assert expect.all "Immich must use persistent media storage with its local database, cache, and ML service" [
    (immich.mediaLocation == "/srv/immich")
    immich.database.enable
    immich.redis.enable
    immich.machine-learning.enable
  ];
  assert lib.assertMsg (immich.settings.server.externalDomain == endpoint.url)
  "Immich must generate links for its private HTTPS endpoint";
  assert expect.all "Immich must offload video encoding and decoding to Kim's VA-API device" [
    (immich.accelerationDevices == ["/dev/dri/renderD128"])
    (immich.settings.ffmpeg.accel == "vaapi")
    immich.settings.ffmpeg.accelDecode
    (server.serviceConfig.DeviceAllow == ["/dev/dri/renderD128"])
    (!server.serviceConfig.PrivateDevices)
    (builtins.elem "render" config.users.users.immich.extraGroups)
  ];
  assert lib.assertMsg (builtins.elem "d /srv/immich 0700 immich immich -" config.systemd.tmpfiles.rules)
  "Immich's non-default media directory must be created with private ownership";
    pkgs.runCommand "immich-config-regression" {} ''
      touch "$out"
    ''
