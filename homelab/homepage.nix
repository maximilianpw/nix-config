{
  config,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  tailnetDomain = config.homelab.tailnet.domain;
  endpoints = homelab.endpoints tailnetDomain;
in {
  # The nixpkgs module exposes no listen-address option; homepage is a
  # Next.js standalone server and binds the address given in $HOSTNAME.
  # Keep it loopback-only like the rest of the homelab; Tailscale Serve
  # reaches it at 127.0.0.1:8082.
  systemd.services.homepage-dashboard.environment.HOSTNAME = "127.0.0.1";

  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    # Homepage refuses requests whose Host header isn't allow-listed.
    allowedHosts = homelab.allowedHosts endpoints.homelab.host;
    openFirewall = false;

    settings = {
      title = "Homelab";
      headerStyle = "clean";
      layout = {
        Services.style = "row";
        Services.columns = 3;
      };
    };

    # Health checks hit the services directly on localhost (no Cloudflare round-trip),
    # except Nextcloud which lives behind a host-matched nginx vhost.
    services = [
      {
        Services = homelab.homepageServices tailnetDomain;
      }
    ];

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/srv";
        };
      }
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
    ];
  };
}
