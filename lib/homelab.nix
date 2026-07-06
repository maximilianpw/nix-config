{lib}: let
  loopbackUrl = port: "http://127.0.0.1:${toString port}";

  privateServices = {
    homelab.port = 8082;
    paperless.port = 28981;
    miniflux.port = 3002;
    syncthing.port = 8384;
    kuma.port = 3001;
  };

  privateHost = tailnetDomain: service: "${service}.${tailnetDomain}";
  privateUrl = tailnetDomain: service: "https://${privateHost tailnetDomain service}";
  privateEndpoint = tailnetDomain: service: let
    serviceConfig = privateServices.${service};
  in {
    inherit (serviceConfig) port;
    host = privateHost tailnetDomain service;
    url = privateUrl tailnetDomain service;
    monitorUrl = loopbackUrl serviceConfig.port;
  };
in {
  defaultTailnetDomain = "tail7161c3.ts.net";
  inherit loopbackUrl privateHost privateServices privateUrl;

  allowedHosts = host: "${host},localhost,127.0.0.1";

  endpoints = tailnetDomain:
    lib.mapAttrs (service: _: privateEndpoint tailnetDomain service) privateServices;

  tailscaleServeServices =
    lib.mapAttrs (_: service: {
      advertised = true;
      endpoints."tcp:443" = loopbackUrl service.port;
    })
    privateServices;

  homepageServices = tailnetDomain: let
    private = lib.mapAttrs (service: _: privateEndpoint tailnetDomain service) privateServices;
  in [
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
        siteMonitor = loopbackUrl 8123;
      };
    }
    {
      Paperless = {
        href = private.paperless.url;
        description = "Documents";
        siteMonitor = private.paperless.monitorUrl;
      };
    }
    {
      Miniflux = {
        href = private.miniflux.url;
        description = "RSS reader";
        siteMonitor = private.miniflux.monitorUrl;
      };
    }
    {
      Syncthing = {
        href = private.syncthing.url;
        description = "File sync";
        siteMonitor = private.syncthing.monitorUrl;
      };
    }
    {
      "Uptime Kuma" = {
        href = private.kuma.url;
        description = "Monitoring";
        siteMonitor = private.kuma.monitorUrl;
      };
    }
  ];
}
