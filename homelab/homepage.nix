{config, ...}: let
  tailnetDomain = config.homelab.tailnet.domain;
  privateUrl = service: "https://${service}.${tailnetDomain}";
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
    allowedHosts = "homelab.${tailnetDomain},localhost,127.0.0.1";
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
        Services = [
          {
            Nextcloud = {
              href = "https://nextcloud.maximilian.pw";
              description = "Files & sync";
              siteMonitor = "https://nextcloud.maximilian.pw";
            };
          }
          {
            "Home Assistant" = {
              href = "https://homeassistant.maximilian.pw";
              description = "Smart home";
              siteMonitor = "http://127.0.0.1:8123";
            };
          }
          {
            Paperless = {
              href = privateUrl "paperless";
              description = "Documents";
              siteMonitor = "http://127.0.0.1:28981";
            };
          }
          {
            Miniflux = {
              href = privateUrl "miniflux";
              description = "RSS reader";
              siteMonitor = "http://127.0.0.1:3002";
            };
          }
          {
            Syncthing = {
              href = privateUrl "syncthing";
              description = "File sync";
              siteMonitor = "http://127.0.0.1:8384";
            };
          }
          {
            "Uptime Kuma" = {
              href = privateUrl "kuma";
              description = "Monitoring";
              siteMonitor = "http://127.0.0.1:3001";
            };
          }
        ];
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
