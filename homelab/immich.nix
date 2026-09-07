{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) immich;
in {
  services.immich = {
    enable = true;
    # NixOS 26.05 is frozen on the unsupported Immich 2.x series. Keep the
    # service on the current package while retaining the stable NixOS module.
    package = pkgs.unstable.immich;
    host = "127.0.0.1";
    inherit (immich) port;
    openFirewall = false;

    # Uploaded originals and generated media belong on the storage SSD. The
    # database and Redis stay local and use Unix sockets without credentials.
    mediaLocation = "/srv/immich";
    database.enable = true;
    redis.enable = true;
    machine-learning.enable = true;

    # Offload video conversion to Kim's Radeon 890M instead of consuming the
    # CPU cores during large mobile-library imports.
    accelerationDevices = ["/dev/dri/renderD128"];
    settings.ffmpeg = {
      accel = "vaapi";
      accelDecode = true;
    };

    # Make generated share links and mobile-app discovery use the private
    # HTTPS endpoint terminated by Tailscale Serve.
    settings.server.externalDomain = immich.url;
  };

  # The upstream module deliberately does not create a non-default media path.
  systemd.tmpfiles.rules = ["d /srv/immich 0700 immich immich -"];
  users.users.immich.extraGroups = ["render"];
}
