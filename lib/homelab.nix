{lib}: let
  loopbackUrl = port: "http://127.0.0.1:${toString port}";

  privateServices = {
    grafana = {
      port = 19004;
      monitorPath = "/api/health";
    };
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
      monitorPath = "/status.php";
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
    monitorUrl = "${loopbackUrl serviceConfig.port}${serviceConfig.monitorPath or ""}";
  };
  publicEndpoint = service: let
    serviceConfig = publicServices.${service};
  in {
    inherit (serviceConfig) host port;
    url = "https://${serviceConfig.host}";
    monitorUrl = "${loopbackUrl serviceConfig.port}${serviceConfig.monitorPath or ""}";
  };
  publicEndpoints = lib.mapAttrs (service: _: publicEndpoint service) publicServices;

  homepageCard = name: endpoint: icon: description: extra: {
    ${name} =
      {
        inherit description icon;
        href = endpoint.url;
        siteMonitor = endpoint.monitorUrl;
      }
      // extra;
  };
  prometheusUrl = loopbackUrl 9090;
  prometheusSummary = {
    widget = {
      type = "prometheusmetric";
      url = prometheusUrl;
      refreshInterval = 20000;
      metrics = [
        {
          label = "CPU";
          query = ''100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
          format = {
            type = "percent";
            options.maximumFractionDigits = 0;
          };
        }
        {
          label = "Memory";
          query = ''100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)'';
          format = {
            type = "percent";
            options.maximumFractionDigits = 0;
          };
        }
        {
          label = "/srv";
          query = ''100 * (1 - node_filesystem_avail_bytes{mountpoint="/srv"} / node_filesystem_size_bytes{mountpoint="/srv"})'';
          format = {
            type = "percent";
            options.maximumFractionDigits = 0;
          };
        }
        {
          label = "Failed";
          query = ''sum(systemd_unit_state{state="failed"})'';
          format.type = "number";
        }
      ];
    };
  };
in {
  defaultTailnetDomain = "tail7161c3.ts.net";
  inherit loopbackUrl privateHost privateServices privateUrl publicEndpoints publicServices;

  allowedHosts = host: "${host},localhost,127.0.0.1";

  endpoints = tailnetDomain:
    lib.mapAttrs (service: _: privateEndpoint tailnetDomain service) privateServices;

  homepageServiceGroups = tailnetDomain: let
    private = lib.mapAttrs (service: _: privateEndpoint tailnetDomain service) privateServices;
    public = publicEndpoints;
    grafanaOverview = "${private.grafana.url}/d/kim-overview/kim-overview";
  in [
    {
      Applications = [
        (homepageCard "Home Assistant" public.homeassistant "home-assistant.png" "Smart home" {})
        (homepageCard "Nextcloud" public.nextcloud "nextcloud.png" "Files, calendar, and sync" {})
        (homepageCard "Paperless" private.paperless "paperless-ngx.png" "Document archive" {})
        (homepageCard "Miniflux" private.miniflux "miniflux.png" "Focused RSS reading" {})
      ];
    }
    {
      Operations = [
        (homepageCard "Grafana" private.grafana "grafana.png" "Kim health and history" (prometheusSummary // {href = grafanaOverview;}))
        (homepageCard "Uptime Kuma" private.kuma "uptime-kuma.png" "Endpoint availability" {})
        (homepageCard "Syncthing" private.syncthing "syncthing.png" "File sync status" {})
        (homepageCard "T3 Code" private.t3code "mdi-code-braces" "Remote AI coding" {})
      ];
    }
  ];
}
