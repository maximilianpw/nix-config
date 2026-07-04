{lib, ...}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
in {
  options.homelab.tailnet.domain = lib.mkOption {
    type = lib.types.str;
    default = homelab.defaultTailnetDomain;
    description = "MagicDNS suffix for private homelab Tailscale Serve endpoints.";
  };

  config.services.tailscale.serve = {
    enable = true;

    # These become https://<service>.tail7161c3.ts.net after the service
    # advertisements are accepted in the tailnet.
    services = homelab.tailscaleServeServices;
  };
}
