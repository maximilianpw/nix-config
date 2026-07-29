{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  endpoints = homelab.endpoints config.homelab.tailnet.domain;
  prometheus = config.services.prometheus;
  inherit (prometheus) exporters;

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
  systemdUnitExpression = "^(${lib.concatMapStringsSep "|" escapeRegex importantSystemdUnits})$";
  grafanaSecretKeySetup = pkgs.writeShellScript "grafana-secret-key-setup" ''
    set -eu

    key_file=/var/lib/grafana/secret_key
    if [ ! -s "$key_file" ]; then
      umask 077
      temporary_key="$(${lib.getExe' pkgs.coreutils "mktemp"} /var/lib/grafana/secret_key.XXXXXX)"
      ${lib.getExe pkgs.openssl} rand -hex 32 > "$temporary_key"
      ${lib.getExe' pkgs.coreutils "mv"} "$temporary_key" "$key_file"
    fi
  '';
  scrape = jobName: port: {
    job_name = jobName;
    static_configs = [
      {targets = ["127.0.0.1:${toString port}"];}
    ];
  };
in {
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    checkConfig = true;
    retentionTime = "30d";
    extraFlags = ["--storage.tsdb.retention.size=5GB"];
    globalConfig = {
      scrape_interval = "20s";
      evaluation_interval = "20s";
    };
    scrapeConfigs = [
      (scrape "node" exporters.node.port)
      (scrape "systemd" exporters.systemd.port)
      (scrape "smartctl" exporters.smartctl.port)
      (scrape "prometheus" prometheus.port)
    ];

    exporters = {
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        openFirewall = false;
        # Keep filesystem series focused on the two operational filesystems;
        # CPU, memory, diskstats, netdev, uptime, and hwmon are default collectors.
        extraFlags = [
          "--collector.filesystem.mount-points-include=^/(|srv)$"
        ];
      };
      systemd = {
        enable = true;
        listenAddress = "127.0.0.1";
        openFirewall = false;
        extraFlags = [
          "--systemd.collector.unit-include=${systemdUnitExpression}"
          "--systemd.collector.enable-restart-count"
        ];
      };
      smartctl = {
        enable = true;
        listenAddress = "127.0.0.1";
        openFirewall = false;
        # Kim's live hardware inventory identifies /srv as nvme0n1 and / as
        # nvme1n1. The NixOS exporter module supplies the narrow NVMe device
        # policy, ACL, and capabilities needed by smartctl.
        devices = [
          "/dev/nvme0n1"
          "/dev/nvme1n1"
        ];
      };
    };
  };

  services.grafana = {
    enable = true;
    openFirewall = false;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = endpoints.grafana.port;
        domain = endpoints.grafana.host;
        root_url = "${endpoints.grafana.url}/";
        # The service is loopback-only, and Homepage probes /api/health through
        # 127.0.0.1. Tailscale Serve remains the only browser-facing ingress.
        enforce_domain = false;
      };
      security = {
        disable_initial_admin_creation = true;
        cookie_secure = true;
        strict_transport_security = true;
        # Grafana 13 requires an explicit encryption key. Generate it once as
        # private disposable state; this deployment provisions no DB secrets.
        secret_key = "$__file{/var/lib/grafana/secret_key}";
      };
      users = {
        allow_sign_up = false;
        allow_org_create = false;
        auto_assign_org = true;
        auto_assign_org_role = "Editor";
      };
      auth.disable_login_form = true;
      "auth.basic".enabled = false;
      "auth.anonymous".enabled = false;
      "auth.proxy" = {
        enabled = true;
        header_name = "Tailscale-User-Login";
        header_property = "email";
        auto_sign_up = true;
        whitelist = [
          "127.0.0.1"
          "::1"
        ];
      };
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
        feedback_links_enabled = false;
      };
      dashboards.default_home_dashboard_path = toString ./grafana/kim-overview.json;
    };
    provision = {
      enable = true;
      datasources.settings = {
        apiVersion = 1;
        prune = true;
        datasources = [
          {
            name = "Prometheus";
            uid = "prometheus";
            type = "prometheus";
            access = "proxy";
            url = homelab.loopbackUrl prometheus.port;
            isDefault = true;
            editable = false;
            jsonData = {
              timeInterval = "20s";
              manageAlerts = false;
            };
          }
        ];
      };
      dashboards.settings = {
        apiVersion = 1;
        providers = [
          {
            name = "homelab";
            type = "file";
            disableDeletion = true;
            editable = false;
            updateIntervalSeconds = 30;
            options = {
              path = ./grafana;
              foldersFromFilesStructure = false;
            };
          }
        ];
      };
    };
  };

  systemd.services.grafana.serviceConfig.ExecStartPre = [grafanaSecretKeySetup];
}
