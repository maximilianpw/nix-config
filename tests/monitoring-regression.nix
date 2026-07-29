{
  config,
  lib,
  pkgs,
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  prometheus = config.services.prometheus;
  inherit (prometheus) exporters;
  grafana = config.services.grafana;
  backupExcludes = config.services.borgbackup.jobs.main.exclude;
  dashboard = builtins.fromJSON (builtins.readFile ../homelab/grafana/kim-overview.json);

  importantSystemdUnits = [
    "grafana.service"
    "prometheus.service"
    "prometheus-node-exporter.service"
    "prometheus-systemd-exporter.service"
    "prometheus-smartctl-exporter.service"
    "tailscaled.service"
    "tailscaled-autoconnect.service"
    "tailscaled-set.service"
    "tailscale-serve.service"
    "postgresql.service"
    "home-assistant.service"
    "nextcloud-cron.service"
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
    "buzz.service"
    "buzz-channels.service"
    "buzz-backup-export.service"
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
  panelTitles = builtins.map (panel: panel.title) dashboard.panels;
  panelQueries = lib.concatMap (panel: builtins.map (target: target.expr) (panel.targets or [])) dashboard.panels;
  queryText = lib.concatStringsSep "\n" panelQueries;
  expectedPanelTitles = [
    "CPU utilization"
    "Memory pressure"
    "Root filesystem"
    "/srv filesystem"
    "Failed important units"
    "Overall SMART status"
    "CPU and load history"
    "Memory history"
    "Filesystem growth"
    "Disk I/O throughput"
    "Disk I/O latency"
    "Network traffic"
    "CPU and NVMe temperatures"
    "Important unit state"
    "Service restart count"
  ];
in
  assert lib.assertMsg (prometheus.listenAddress == "127.0.0.1")
  "Prometheus must bind only to IPv4 loopback";
  assert lib.assertMsg (lib.all (exporter: exporter.listenAddress == "127.0.0.1") [
    exporters.node
    exporters.systemd
    exporters.smartctl
  ])
  "Prometheus exporters must bind only to IPv4 loopback";
  assert lib.assertMsg (lib.all (exporter: !exporter.openFirewall) [
    exporters.node
    exporters.systemd
    exporters.smartctl
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
      whitelist = [
        "127.0.0.1"
        "::1"
      ];
    })
  "Grafana auth proxy must trust only Tailscale's identity header from loopback";
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
  ])
  "Kim Overview queries must cover the pinned exporters' required metrics";
  assert lib.assertMsg (lib.all (path: builtins.elem path backupExcludes) [
    "/var/lib/prometheus2"
    "/var/lib/grafana"
  ])
  "Disposable Prometheus and Grafana state must stay excluded from Borg";
  assert lib.assertMsg (builtins.hasAttr "grafana" homelab.privateServices)
  "Grafana must remain in the Tailscale Serve-derived private service inventory";
    pkgs.runCommand "monitoring-regression" {} ''
      touch "$out"
    ''
