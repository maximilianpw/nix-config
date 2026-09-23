{lib}: let
  services = import ./homelab-inventory.nix {inherit lib;};
  loopbackUrl = port: "http://127.0.0.1:${toString port}";
  # Shared infrastructure outside the service inventory. Every record's
  # `units` are important for monitoring and post-switch checks.
  infrastructure = {
    cloudflare = rec {
      tunnelId = "5b712ae4-3ce4-4499-9cb7-a57cde1c571f";
      unit = "cloudflared-tunnel-${tunnelId}.service";
      units = [unit];
    };
    postgresql.units = ["postgresql.service"];
    postgresqlBackup = rec {
      archivePath = "/var/backup/postgresql";
      unit = "postgresqlBackup.service";
      units = [unit];
    };
    monitoring.units = [
      "prometheus-node-exporter.service"
      "prometheus-blackbox-exporter.service"
      "prometheus-systemd-exporter.service"
      "prometheus-smartctl-exporter.service"
      "prometheus-postgres-exporter.service"
      "alertmanager.service"
      "homelab-systemd-metrics.service"
      "homelab-systemd-metrics.timer"
      "homelab-container-audit.service"
      "homelab-container-audit.timer"
    ];
    tailscale.units = [
      "tailscaled.service"
      "tailscaled-set.service"
      "tailscale-serve.service"
    ];
    borg.units = [
      "borgbackup-job-main.service"
      "borgbackup-job-main.timer"
      "borgbackup-check-main.service"
      "borgbackup-check-main.timer"
      "borgbackup-verify-main.service"
      "borgbackup-verify-main.timer"
    ];
  };
  byExposure = exposure:
    lib.filterAttrs (_: service: service.endpoint.exposure == exposure) services;
  endpointView = _: service:
    {
      inherit (service.endpoint) monitorPath port publicMonitorPath;
    }
    // lib.optionalAttrs (service.endpoint.hostname != null) {
      host = service.endpoint.hostname;
    };
  privateServices = lib.mapAttrs endpointView (byExposure "tailnet");
  publicServices = lib.mapAttrs endpointView (byExposure "public");

  tailnetDomain = "liger-shilling.ts.net";
  privateHost = service: "${service}.${tailnetDomain}";
  privateUrl = service: "https://${privateHost service}";
  privateEndpoint = service: let
    serviceConfig = privateServices.${service};
  in {
    inherit (serviceConfig) port;
    host = privateHost service;
    url = privateUrl service;
    monitorUrl = "${loopbackUrl serviceConfig.port}${serviceConfig.monitorPath}";
  };
  publicEndpoint = service: let
    serviceConfig = publicServices.${service};
    url = "https://${serviceConfig.host}";
  in {
    inherit (serviceConfig) host port;
    inherit url;
    monitorUrl = "${loopbackUrl serviceConfig.port}${serviceConfig.monitorPath}";
    publicMonitorUrl = "${url}${
      if serviceConfig.publicMonitorPath == null
      then serviceConfig.monitorPath
      else serviceConfig.publicMonitorPath
    }";
  };
  publicEndpoints = lib.mapAttrs (service: _: publicEndpoint service) publicServices;
  monitoredOrigins =
    lib.mapAttrs (_: service: {
      inherit (service.endpoint) port;
      monitorUrl = "${loopbackUrl service.endpoint.port}${service.endpoint.monitorPath}";
    }) (lib.filterAttrs (_: service:
      service.endpoint.exposure != "none" && service.endpoint.port != null)
    services);

  homepageCard = name: endpoint: icon: description: extra: {
    ${name} =
      {
        inherit description icon;
        href = endpoint.url;
        siteMonitor = endpoint.monitorUrl;
      }
      // extra;
  };
  prometheusUrl = loopbackUrl services.prometheus.endpoint.port;
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
  presented = lib.filterAttrs (_: service: service.presentation != null) services;
  presentationEntries = lib.mapAttrsToList (name: service: {inherit name service;}) presented;
  cardsFor = group: let
    endpoints = privateEndpoints // publicEndpoints;
    selected = builtins.filter (entry: entry.service.presentation.group == group) presentationEntries;
    ordered = lib.sort (left: right: left.service.presentation.order < right.service.presentation.order) selected;
    cardFor = entry: let
      inherit (entry) name service;
      inherit (service) presentation;
      extra =
        if name == "grafana"
        then prometheusSummary // {href = "${endpoints.grafana.url}/d/kim-overview/kim-overview";}
        else {};
    in
      homepageCard presentation.title endpoints.${name} presentation.icon presentation.description extra;
  in
    map cardFor ordered;
  privateEndpoints = lib.mapAttrs (service: _: privateEndpoint service) privateServices;
  quiesceUnits = phase:
    lib.concatMap (
      service:
        map (entry: entry.unit) (builtins.filter (entry: entry.until == phase) service.backup.quiesce)
    ) (builtins.attrValues services);
  expectedDatabases = lib.unique (lib.filter (database: database != null) (map (service: service.state.database) (builtins.attrValues services)));
  infrastructureUnits = lib.concatMap (record: record.units) (builtins.attrValues infrastructure);
in {
  inherit infrastructure loopbackUrl monitoredOrigins privateHost privateServices privateUrl publicEndpoints publicServices services tailnetDomain;

  allowedHosts = host: "${host},localhost,127.0.0.1";
  endpoints = privateEndpoints;

  backup = {
    archivePaths = lib.unique (
      lib.concatMap (service: service.backup.archivePaths) (builtins.attrValues services)
      ++ lib.optional (expectedDatabases != []) infrastructure.postgresqlBackup.archivePath
    );
    dumpUnits = quiesceUnits "dump";
    archiveUnits = quiesceUnits "archive";
    inherit expectedDatabases;
    primaryStatePaths = lib.unique (lib.concatMap (service: service.state.paths) (builtins.attrValues services));
    disposableServices = builtins.attrNames (lib.filterAttrs (_: service: service.state.disposable) services);
    recovery = lib.mapAttrs (_: service: service.recovery) (
      lib.filterAttrs (_: service: service.state.kind != "none") services
    );
  };

  srvConsumers = lib.unique (map (lib.removeSuffix ".service") (lib.concatMap (service: service.storage.units) (builtins.attrValues services)));
  importantSystemdUnits = lib.unique (infrastructureUnits ++ lib.concatMap (service: service.operations.units) (builtins.attrValues services));

  homepageServiceGroups = [
    {Applications = cardsFor "applications";}
    {Operations = cardsFor "operations";}
  ];
}
