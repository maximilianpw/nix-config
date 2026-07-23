{lib}: let
  loopbackUrl = port: "http://127.0.0.1:${toString port}";

  privateServices = {
    buzz.port = 19003;
    homelab.port = 19082;
    paperless.port = 28981;
    miniflux.port = 19002;
    syncthing.port = 19384;
    t3code.port = 51000;
    kuma.port = 19001;
  };

  publicServices = {
    nextcloud = {
      host = "nextcloud.maximilian.pw";
      port = 19080;
    };
    homeassistant = {
      host = "homeassistant.maximilian.pw";
      port = 19123;
    };
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
  publicEndpoint = service: let
    serviceConfig = publicServices.${service};
  in {
    inherit (serviceConfig) host port;
    url = "https://${serviceConfig.host}";
    monitorUrl = loopbackUrl serviceConfig.port;
  };
  publicEndpoints = lib.mapAttrs (service: _: publicEndpoint service) publicServices;
in {
  defaultTailnetDomain = "tail7161c3.ts.net";
  inherit loopbackUrl privateHost privateServices privateUrl publicEndpoints publicServices;

  allowedHosts = host: "${host},localhost,127.0.0.1";

  endpoints = tailnetDomain:
    lib.mapAttrs (service: _: privateEndpoint tailnetDomain service) privateServices;

  homepageServices = tailnetDomain: let
    private = lib.mapAttrs (service: _: privateEndpoint tailnetDomain service) privateServices;
    public = publicEndpoints;
  in [
    {
      Nextcloud = {
        href = public.nextcloud.url;
        description = "Files & sync";
        siteMonitor = public.nextcloud.url;
      };
    }
    {
      "Home Assistant" = {
        href = public.homeassistant.url;
        description = "Smart home";
        siteMonitor = public.homeassistant.monitorUrl;
      };
    }
    {
      Buzz = {
        href = private.buzz.url;
        description = "Human and agent workspace";
        siteMonitor = private.buzz.monitorUrl;
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
      "T3 Code" = {
        href = private.t3code.url;
        description = "Remote AI coding";
        siteMonitor = private.t3code.monitorUrl;
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
