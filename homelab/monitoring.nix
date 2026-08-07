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

  escapeRegex = lib.replaceStrings ["."] ["[.]"];
  systemdUnitExpression = "^(${lib.concatMapStringsSep "|" escapeRegex homelab.importantSystemdUnits})$";
  grafanaHomeDashboard = pkgs.writeText "kim-overview.json" (builtins.readFile ./grafana/kim-overview.json);
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
  alert = name: expression: duration: severity: summary: {
    alert = name;
    expr = expression;
    "for" = duration;
    labels = {inherit severity;};
    annotations = {inherit summary;};
  };
  blackboxConfig = (pkgs.formats.yaml {}).generate "homelab-blackbox.yaml" {
    modules.http_2xx = {
      prober = "http";
      timeout = "10s";
      http = {
        preferred_ip_protocol = "ip4";
        follow_redirects = true;
        # Tunarr's health endpoint returns HTTP 200 even when a component is
        # unhealthy. Treat its compact JSON error marker as a failed probe.
        fail_if_body_matches_regexp = [''"type":"error"''];
      };
    };
  };
  publicIngressScrape = {
    job_name = "public-ingress";
    metrics_path = "/probe";
    params.module = ["http_2xx"];
    static_configs = [
      {targets = map (endpoint: endpoint.url) (builtins.attrValues homelab.publicEndpoints);}
    ];
    relabel_configs = [
      {
        source_labels = ["__address__"];
        target_label = "__param_target";
      }
      {
        source_labels = ["__param_target"];
        target_label = "instance";
      }
      {
        target_label = "__address__";
        replacement = "127.0.0.1:${toString exporters.blackbox.port}";
      }
    ];
  };
  localBackendScrape = {
    job_name = "local-backends";
    metrics_path = "/probe";
    params.module = ["http_2xx"];
    static_configs = [
      {targets = map (endpoint: endpoint.monitorUrl) (builtins.attrValues homelab.monitoredOrigins);}
    ];
    inherit (publicIngressScrape) relabel_configs;
  };
  homelabRules = (pkgs.formats.yaml {}).generate "homelab-prometheus-rules.yaml" {
    groups = [
      {
        name = "homelab-operations";
        rules = [
          (alert "HomelabNodeExporterDown" ''absent(up{job="node"}) or up{job="node"} == 0'' "5m" "critical" "The node exporter is absent or unreachable")
          (alert "HomelabSystemdExporterDown" ''absent(up{job="systemd"}) or up{job="systemd"} == 0'' "5m" "critical" "The systemd exporter is absent or unreachable")
          (alert "HomelabSmartctlExporterDown" ''absent(up{job="smartctl"}) or up{job="smartctl"} == 0'' "5m" "critical" "The SMART exporter is absent or unreachable")
          (alert "HomelabLocalBackendDown" ''absent(probe_success{job="local-backends"}) or probe_success{job="local-backends"} == 0 or up{job="local-backends"} == 0'' "10m" "critical" "A declared homelab backend is unhealthy")
          (alert "HomelabPublicIngressDown" ''absent(probe_success{job="public-ingress"}) or probe_success{job="public-ingress"} == 0 or up{job="public-ingress"} == 0'' "10m" "critical" "A declared public ingress endpoint is unreachable")
          (alert "HomelabBackupStale" ''absent(homelab_backup_last_success_timestamp_seconds) or (time() - homelab_backup_last_success_timestamp_seconds > 129600)'' "15m" "critical" "No successful local backup has been recorded in 36 hours")
          (alert "HomelabBorgCheckStale" ''absent(homelab_borg_check_last_success_timestamp_seconds) or (time() - homelab_borg_check_last_success_timestamp_seconds > 777600)'' "30m" "critical" "No successful Borg consistency check has been recorded in 9 days")
          (alert "HomelabSrvAbsent" ''absent(node_filesystem_size_bytes{mountpoint="/srv",fstype!="rootfs"})'' "5m" "critical" "/srv is absent from node-exporter filesystem metrics")
          (alert "HomelabFilesystemWarning" ''100 * (1 - node_filesystem_avail_bytes{mountpoint=~"/|/srv"} / node_filesystem_size_bytes{mountpoint=~"/|/srv"}) > 80'' "30m" "warning" "A primary filesystem is more than 80% full")
          (alert "HomelabFilesystemCritical" ''100 * (1 - node_filesystem_avail_bytes{mountpoint=~"/|/srv"} / node_filesystem_size_bytes{mountpoint=~"/|/srv"}) > 90'' "15m" "critical" "A primary filesystem is more than 90% full")
          (alert "HomelabSmartFailure" ''smartctl_device_smart_status != 1'' "5m" "critical" "SMART reports an unhealthy storage device")
          (alert "HomelabNvmeTemperatureHigh" ''smartctl_device_temperature{temperature_type="current"} > 80'' "15m" "warning" "An NVMe device has remained above 80°C")
          (alert "HomelabPostgresExporterDown" ''absent(pg_up) or pg_up == 0'' "5m" "critical" "The PostgreSQL exporter cannot query PostgreSQL")
          (alert "HomelabImportantUnitFailed" ''systemd_unit_state{state="failed"} == 1'' "10m" "critical" "An important homelab systemd unit is failed")
          (alert "HomelabRepeatedServiceRestarts" ''increase(systemd_service_restart_total[30m]) > 3'' "10m" "warning" "An important homelab service is repeatedly restarting")
        ];
      }
    ];
  };
  loopbackPorts = map (service: service.endpoint.port) (
    lib.filter (
      service: service.endpoint.exposure != "none" && service.endpoint.port != null
    ) (builtins.attrValues homelab.services)
  );
  tailscaleServiceNames = map (service: service.tailscaleServiceName) (
    lib.filter (service: service.tailscaleServiceName != null) (builtins.attrValues homelab.services)
  );
  homelabCheck = pkgs.writeShellApplication {
    name = "homelab-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.iproute2
      pkgs.jq
      pkgs.systemd
      pkgs.tailscale
      pkgs.util-linux
    ];
    text = ''
      export FINDMNT_BIN=${lib.getExe' pkgs.util-linux "findmnt"}
      export SYSTEMCTL_BIN=${lib.getExe' pkgs.systemd "systemctl"}
      export SS_BIN=${lib.getExe' pkgs.iproute2 "ss"}
      export TAILSCALE_BIN=${lib.getExe config.services.tailscale.package}
      export JQ_BIN=${lib.getExe pkgs.jq}
      export CURL_BIN=${lib.getExe pkgs.curl}
      export ID_BIN=${lib.getExe' pkgs.coreutils "id"}
      export HOMELAB_REQUIRED_MOUNTS=${lib.escapeShellArg "/ /srv /mnt/backups"}
      export HOMELAB_OPTIONAL_AUTOMOUNTS=${lib.escapeShellArg "/mnt/backups"}
      export HOMELAB_IMPORTANT_UNITS=${lib.escapeShellArg (lib.concatStringsSep " " homelab.importantSystemdUnits)}
      export HOMELAB_LOOPBACK_PORTS=${lib.escapeShellArg (lib.concatMapStringsSep " " toString loopbackPorts)}
      export HOMELAB_TAILSCALE_SERVICES=${lib.escapeShellArg (lib.concatStringsSep " " tailscaleServiceNames)}
      export HOMELAB_CLOUDFLARED_UNIT=${lib.escapeShellArg homelab.infrastructure.cloudflare.unit}
      export HOMELAB_PROMETHEUS_URL=${lib.escapeShellArg (homelab.loopbackUrl prometheus.port)}
      export HOMELAB_INSPECT_BIN=homelab-backup-inspect
      exec ${lib.getExe pkgs.bash} ${../scripts/homelab-check.sh} "$@"
    '';
  };
in {
  environment.systemPackages = [homelabCheck];

  services = {
    prometheus = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = homelab.services.prometheus.endpoint.port;
      checkConfig = true;
      retentionTime = "30d";
      extraFlags = ["--storage.tsdb.retention.size=5GB"];
      globalConfig = {
        scrape_interval = "20s";
        evaluation_interval = "20s";
      };
      ruleFiles = [homelabRules];
      scrapeConfigs = [
        (scrape "node" exporters.node.port)
        (scrape "systemd" exporters.systemd.port)
        (scrape "smartctl" exporters.smartctl.port)
        (scrape "postgres" exporters.postgres.port)
        (scrape "prometheus" prometheus.port)
        localBackendScrape
        publicIngressScrape
      ];

      exporters = {
        blackbox = {
          enable = true;
          listenAddress = "127.0.0.1";
          openFirewall = false;
          configFile = blackboxConfig;
        };
        node = {
          enable = true;
          listenAddress = "127.0.0.1";
          openFirewall = false;
          # Keep filesystem series focused on the two operational filesystems;
          # CPU, memory, diskstats, netdev, uptime, and hwmon are default collectors.
          enabledCollectors = ["textfile"];
          extraFlags = [
            "--collector.filesystem.mount-points-include=^/(|srv)$"
            "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files"
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
          # These are the currently monitored NVMe namespaces, not stable disk
          # identities. Reconcile them with model/serial data using
          # docs/homelab-storage.md after hardware changes.
          devices = [
            "/dev/nvme0n1"
            "/dev/nvme1n1"
          ];
        };
        postgres = {
          enable = true;
          listenAddress = "127.0.0.1";
          openFirewall = false;
          # A matching OS and database role lets peer authentication work without
          # a stored credential or PostgreSQL superuser access.
          dataSourceName = "user=postgres-exporter database=postgres host=/run/postgresql sslmode=disable";
          extraFlags = lib.optionals (lib.versionAtLeast config.services.postgresql.package.version "17") [
            "--collector.stat_checkpointer"
          ];
        };
      };
    };

    postgresql.ensureUsers = [{name = "postgres-exporter";}];

    grafana = {
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
          # Tailscale Services strips spoofed identity headers, injects its own,
          # and preserves the client's Tailnet source address. Grafana expects a
          # comma-separated string here; a Nix list is rendered space-separated.
          whitelist = "127.0.0.1, ::1, 100.64.0.0/10, fd7a:115c:a1e0::/48";
        };
        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
          check_for_plugin_updates = false;
          feedback_links_enabled = false;
        };
        dashboards.default_home_dashboard_path = "${grafanaHomeDashboard}";
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
  };

  systemd.services = {
    # ensureUsers runs in postgresql-setup, so grant privileges only after that
    # service has created the exporter role. Running this in postgresql.postStart
    # prevents PostgreSQL itself from starting on a fresh role declaration.
    postgresql-setup.postStart = lib.mkAfter ''
      ${lib.getExe' config.services.postgresql.finalPackage "psql"} -tAc 'GRANT pg_monitor TO "postgres-exporter"'
    '';
    prometheus-postgres-exporter = {
      after = ["postgresql-setup.service"];
      requires = ["postgresql-setup.service"];
    };
    grafana.serviceConfig.ExecStartPre = [grafanaSecretKeySetup];
  };
}
