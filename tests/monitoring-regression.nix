{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  prometheus = config.services.prometheus;
  inherit (prometheus) exporters;
  postgresql = config.services.postgresql;
  grafana = config.services.grafana;
  backupExcludes = config.services.borgbackup.jobs.main.exclude;
  dashboard = builtins.fromJSON (builtins.readFile ../homelab/grafana/kim-overview.json);

  importantSystemdUnits = [
    "grafana.service"
    "prometheus.service"
    "prometheus-node-exporter.service"
    "prometheus-systemd-exporter.service"
    "prometheus-smartctl-exporter.service"
    "prometheus-postgres-exporter.service"
    "tailscaled.service"
    "tailscaled-autoconnect.service"
    "tailscaled-set.service"
    "tailscale-serve.service"
    "postgresql.service"
    "home-assistant.service"
    "nextcloud-cron.service"
    "nextcloud-update-store-apps.service"
    "nextcloud-update-store-apps.timer"
    "nginx.service"
    "phpfpm-nextcloud.service"
    "paperless-consumer.service"
    "paperless-scheduler.service"
    "paperless-task-queue.service"
    "paperless-web.service"
    "paperless-exporter.service"
    "miniflux.service"
    "syncthing.service"
    "uptime-kuma.service"
    "homepage-dashboard.service"
    "vaultwarden.service"
    "postgresqlBackup.service"
    "borgbackup-job-main.service"
    "borgbackup-job-main.timer"
    "borgbackup-check-main.service"
    "borgbackup-check-main.timer"
  ];
  escapeRegex = lib.replaceStrings ["."] ["\\."];
  expectedSystemdExpression = "^(${lib.concatMapStringsSep "|" escapeRegex importantSystemdUnits})$";
  systemdIncludeFlag = "--systemd.collector.unit-include=${expectedSystemdExpression}";
  datasource = builtins.head grafana.provision.datasources.settings.datasources;
  provider = builtins.head grafana.provision.dashboards.settings.providers;
  scrapeJobNames = builtins.map (scrapeConfig: scrapeConfig.job_name) prometheus.scrapeConfigs;
  panelTitles = builtins.map (panel: panel.title) dashboard.panels;
  panelQueries = lib.concatMap (panel: builtins.map (target: target.expr) (panel.targets or [])) dashboard.panels;
  cpuBusyQueries = builtins.filter (query: lib.hasInfix ''mode="idle"'' query) panelQueries;
  queryText = lib.concatStringsSep "\n" panelQueries;
  privateServicePorts = lib.concatMap (
    service:
      [service.port]
      ++ lib.optional (service ? healthPort) service.healthPort
      ++ lib.attrValues (service.pathBackends or {})
  ) (lib.attrValues homelab.privateServices);
  expectedPanelTitles = [
    "CPU busy"
    "Memory pressure"
    "Root filesystem"
    "/srv filesystem"
    "Operational issues"
    "Overall SMART status"
    "CPU work, I/O wait, and load"
    "Memory history"
    "Filesystem growth"
    "Disk I/O throughput"
    "Disk I/O latency"
    "Network traffic"
    "CPU and NVMe temperatures"
    "Important unit state"
    "Service restart count"
    "PostgreSQL checkpoint activity"
  ];
in
  assert lib.assertMsg (prometheus.listenAddress == "127.0.0.1")
  "Prometheus must bind only to IPv4 loopback";
  assert lib.assertMsg (lib.all (exporter: exporter.listenAddress == "127.0.0.1") [
    exporters.node
    exporters.systemd
    exporters.smartctl
    exporters.postgres
  ])
  "Prometheus exporters must bind only to IPv4 loopback";
  assert lib.assertMsg (lib.all (exporter: !exporter.openFirewall) [
    exporters.node
    exporters.systemd
    exporters.smartctl
    exporters.postgres
  ])
  "Prometheus exporter firewall ports must stay closed";
  assert lib.assertMsg (prometheus.retentionTime == "30d")
  "Prometheus retention must remain 30 days";
  assert lib.assertMsg (builtins.elem "--storage.tsdb.retention.size=5GB" prometheus.extraFlags)
  "Prometheus storage must remain capped at 5 GB";
  assert lib.assertMsg prometheus.checkConfig
  "Prometheus configuration checking must remain enabled";
  assert lib.assertMsg (exporters.smartctl.devices
    == [
      "/dev/nvme0n1"
      "/dev/nvme1n1"
    ])
  "SMART exporter must monitor both of Kim's NVMe namespaces explicitly";
  assert lib.assertMsg (builtins.elem systemdIncludeFlag exporters.systemd.extraFlags)
  "systemd exporter must include exactly the operational unit allow-list";
  assert lib.assertMsg (!exporters.postgres.runAsLocalSuperUser)
  "PostgreSQL exporter must not run as the database superuser";
  assert lib.assertMsg (exporters.postgres.dataSourceName
    == "user=postgres-exporter database=postgres host=/run/postgresql sslmode=disable")
  "PostgreSQL exporter must authenticate its dedicated role over the local Unix socket";
  assert lib.assertMsg (lib.any (user: user.name == "postgres-exporter") postgresql.ensureUsers)
  "PostgreSQL must create the exporter's matching peer-authenticated role";
  assert lib.assertMsg (lib.hasInfix ''GRANT pg_monitor TO "postgres-exporter"'' config.systemd.services.postgresql-setup.postStart)
  "PostgreSQL exporter role must receive monitoring privileges after ensureUsers creates it";
  assert lib.assertMsg (!lib.hasInfix ''GRANT pg_monitor TO "postgres-exporter"'' config.systemd.services.postgresql.postStart)
  "PostgreSQL startup must not depend on the exporter role already existing";
  assert lib.assertMsg (lib.all (dependencies: builtins.elem "postgresql-setup.service" dependencies) [
    config.systemd.services.prometheus-postgres-exporter.after
    config.systemd.services.prometheus-postgres-exporter.requires
  ])
  "PostgreSQL exporter must wait for its database role and grants";
  assert lib.assertMsg ((lib.versionAtLeast postgresql.package.version "17")
    == builtins.elem "--collector.stat_checkpointer" exporters.postgres.extraFlags)
  "PostgreSQL 17 and newer must enable the replacement checkpoint collector";
  assert lib.assertMsg (builtins.elem "postgres" scrapeJobNames)
  "Prometheus must scrape the local PostgreSQL exporter";
  assert lib.assertMsg (builtins.elem "--systemd.collector.enable-restart-count" exporters.systemd.extraFlags)
  "systemd exporter must expose restart counts";
  assert lib.assertMsg (builtins.length exporters.systemd.extraFlags == 2)
  "systemd exporter must not gain broad collectors outside the allow-list";
  assert lib.assertMsg (grafana.settings.server.http_addr == "127.0.0.1")
  "Grafana must bind only to IPv4 loopback";
  assert lib.assertMsg (grafana.settings.server.http_port == homelab.privateServices.grafana.port)
  "Grafana must use its homelab-assigned private port";
  assert lib.assertMsg (!grafana.openFirewall)
  "Grafana must not open a LAN firewall port";
  assert lib.assertMsg (grafana.settings."auth.proxy"
    == {
      enabled = true;
      header_name = "Tailscale-User-Login";
      header_property = "email";
      auto_sign_up = true;
      whitelist = "127.0.0.1, ::1, 100.64.0.0/10, fd7a:115c:a1e0::/48";
    })
  "Grafana auth proxy must trust Tailscale identity headers only from local and Tailnet source ranges";
  assert lib.assertMsg (!grafana.settings."auth.anonymous".enabled)
  "Grafana anonymous access must remain disabled";
  assert lib.assertMsg (!grafana.settings."auth.basic".enabled)
  "Grafana basic authentication must remain disabled";
  assert lib.assertMsg (!grafana.settings.users.allow_sign_up)
  "Grafana public signup must remain disabled";
  assert lib.assertMsg grafana.settings.auth.disable_login_form
  "Grafana must not show a second login form behind Tailscale";
  assert lib.assertMsg (grafana.settings.users.auto_assign_org_role == "Editor")
  "Tailnet users must receive enough access for Grafana Explore";
  assert lib.assertMsg (grafana.settings.security.secret_key == "$__file{/var/lib/grafana/secret_key}")
  "Grafana's generated encryption key must stay outside the Nix store";
  assert lib.assertMsg (datasource.uid == "prometheus" && datasource.isDefault && !datasource.editable)
  "Grafana must provision Prometheus as its immutable default datasource";
  assert lib.assertMsg (datasource.url == homelab.loopbackUrl prometheus.port)
  "Grafana must query Prometheus over loopback";
  assert lib.assertMsg (!provider.editable && provider.disableDeletion)
  "The repository-provisioned Grafana dashboard must stay read-only";
  assert lib.assertMsg (dashboard.uid == "kim-overview" && dashboard.title == "Kim Overview")
  "Kim Overview must retain its stable title and UID";
  assert lib.assertMsg (panelTitles == expectedPanelTitles)
  "Kim Overview must retain its concise panel set and order";
  assert lib.assertMsg (lib.all (panel: panel.datasource.uid == "prometheus") dashboard.panels)
  "Every Kim Overview panel must use the provisioned Prometheus datasource UID";
  assert lib.assertMsg (
    builtins.length cpuBusyQueries
    == 2
    && lib.all (query: lib.hasInfix ''- avg(rate(node_cpu_seconds_total{mode="iowait"}'' query) cpuBusyQueries
    && lib.hasInfix ''100 * avg(rate(node_cpu_seconds_total{mode="iowait"}'' queryText
  )
  "Every CPU-busy query must exclude I/O wait, which must also remain visible separately";
  assert lib.assertMsg (lib.all (metric: lib.hasInfix metric queryText) [
    "node_cpu_seconds_total"
    "node_memory_MemAvailable_bytes"
    "node_filesystem_avail_bytes"
    "node_disk_read_bytes_total"
    "node_disk_read_time_seconds_total"
    "node_network_receive_bytes_total"
    "node_hwmon_temp_celsius"
    "smartctl_device_temperature"
    "smartctl_device_smart_status"
    "systemd_unit_state"
    "systemd_service_restart_total"
    "pg_up"
    "pg_stat_bgwriter_checkpoints_timed_total"
    "pg_stat_bgwriter_checkpoints_req_total"
    "pg_stat_bgwriter_buffers_checkpoint_total"
    "pg_stat_checkpointer_num_timed_total"
    "pg_stat_checkpointer_num_requested_total"
    "pg_stat_checkpointer_buffers_written_total"
  ])
  "Kim Overview queries must cover the pinned exporters' required metrics";
  assert lib.assertMsg (lib.all (path: builtins.elem path backupExcludes) [
    "/var/lib/prometheus2"
    "/var/lib/grafana"
  ])
  "Disposable Prometheus and Grafana state must stay excluded from Borg";
  assert lib.assertMsg (builtins.hasAttr "grafana" homelab.privateServices)
  "Grafana must remain in the Tailscale Serve-derived private service inventory";
  assert lib.assertMsg (builtins.length privateServicePorts == builtins.length (lib.unique privateServicePorts))
  "Every loopback-bound private service port must be unique";
    pkgs.runCommand "monitoring-regression" {} ''
      touch "$out"
    ''
