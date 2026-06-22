{...}: {
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8082;
    # Homepage refuses requests whose Host header isn't allow-listed.
    allowedHosts = "homelab.maximilian.pw";
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
              href = "https://paperless.maximilian.pw";
              description = "Documents";
              siteMonitor = "http://127.0.0.1:28981";
            };
          }
          {
            Miniflux = {
              href = "https://miniflux.maximilian.pw";
              description = "RSS reader";
              siteMonitor = "http://127.0.0.1:3002";
            };
          }
          {
            Birdclaw = {
              href = "https://birdclaw.maximilian.pw";
              description = "Twitter archive";
              siteMonitor = "http://127.0.0.1:3003";
            };
          }
          {
            Syncthing = {
              href = "https://syncthing.maximilian.pw";
              description = "File sync";
              siteMonitor = "http://127.0.0.1:8384";
            };
          }
          {
            "Uptime Kuma" = {
              href = "https://kuma.maximilian.pw";
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
