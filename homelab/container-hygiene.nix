{
  config,
  pkgs,
  ...
}: let
  metricsDirectory = "/var/lib/prometheus-node-exporter-text-files";
  containerAudit = pkgs.writeShellApplication {
    name = "homelab-container-audit";
    runtimeInputs = [
      config.virtualisation.docker.package
      pkgs.coreutils
      pkgs.gawk
      pkgs.jq
    ];
    text = ''
      export DOCKER_BIN=${config.virtualisation.docker.package}/bin/docker
      export DATE_BIN=${pkgs.coreutils}/bin/date
      export JQ_BIN=${pkgs.jq}/bin/jq
      export HOMELAB_METRICS_DIR=${metricsDirectory}
      export HOMELAB_CONTAINER_STALE_AFTER_SECONDS=259200
      exec ${pkgs.bash}/bin/bash ${../scripts/homelab-container-audit.sh}
    '';
  };
in {
  environment.systemPackages = [containerAudit];

  systemd = {
    tmpfiles.settings."10-homelab-metrics"."${metricsDirectory}".d = {
      user = "root";
      group = "root";
      mode = "0755";
    };

    timers.homelab-container-audit = {
      description = "Audit long-running Docker containers";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "10m";
        OnCalendar = "daily";
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };

    services.homelab-container-audit = {
      description = "Report long-running Docker containers without changing them";
      requires = ["docker.service"];
      after = ["docker.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${containerAudit}/bin/homelab-container-audit";
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [metricsDirectory];
        RestrictAddressFamilies = ["AF_UNIX"];
      };
    };
  };
}
