{lib, ...}: {
  options.homelab.tailnet.domain = lib.mkOption {
    type = lib.types.str;
    default = "tail7161c3.ts.net";
    description = "MagicDNS suffix for private homelab Tailscale Serve endpoints.";
  };

  config.services.tailscale.serve = {
    enable = true;

    # These become https://<service>.tail7161c3.ts.net after the service
    # advertisements are accepted in the tailnet.
    services = {
      homelab = {
        advertised = true;
        endpoints."tcp:443" = "http://127.0.0.1:8082";
      };
      paperless = {
        advertised = true;
        endpoints."tcp:443" = "http://127.0.0.1:28981";
      };
      miniflux = {
        advertised = true;
        endpoints."tcp:443" = "http://127.0.0.1:3002";
      };
      syncthing = {
        advertised = true;
        endpoints."tcp:443" = "http://127.0.0.1:8384";
      };
      kuma = {
        advertised = true;
        endpoints."tcp:443" = "http://127.0.0.1:3001";
      };
      t3code = {
        advertised = true;
        endpoints."tcp:443" = "http://127.0.0.1:51000";
      };
    };
  };
}
