{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit ((homelab.endpoints config.homelab.tailnet.domain)) immich;
in {
  services.immich = {
    enable = true;
    host = "127.0.0.1";
    inherit (immich) port;
    openFirewall = false;

    # Uploaded originals and generated media belong on the storage SSD. The
    # database and Redis stay local and use Unix sockets without credentials.
    mediaLocation = "/srv/immich";
    database.enable = true;
    redis.enable = true;
    machine-learning.enable = true;

    # Make generated share links and mobile-app discovery use the private
    # HTTPS endpoint terminated by Tailscale Serve.
    settings.server.externalDomain = immich.url;
  };

  # The upstream module deliberately does not create a non-default media path.
  systemd.tmpfiles.rules = ["d /srv/immich 0700 immich immich -"];
}
