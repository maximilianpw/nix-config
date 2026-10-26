{
  config,
  currentSystemName,
  currentSystemUser,
  lib,
  pkgs,
  ...
}: let
  cliProxy = import ./config.nix;
  homeDirectory = "/home/${currentSystemUser}";
  runServer = currentSystemName == "kim";
  stats = config.homelab.cliproxyapi.quotaStatistics;
  useStatistics = runServer && stats.enable;
in {
  options.homelab.cliproxyapi.quotaStatistics = {
    enable = lib.mkEnableOption "the pinned Fleet backend and local ClickHouse on Kim";
    reviewedBackendRevision = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Exact CLIProxyAPI source revision approved for activation, after reviewing backend PR #1. Must match the Fleet package pin; null keeps activation gated.";
    };
  };

  config = {
    assertions = lib.optionals stats.enable [
      {
        assertion = runServer;
        message = "Quota statistics are supported only on Kim.";
      }
      {
        assertion = stats.reviewedBackendRevision == config.services.cliproxyapi.package.src.rev;
        message = "Review/merge CLIProxyAPI PR #1 and set quotaStatistics.reviewedBackendRevision to the exact Fleet backend source revision before enabling.";
      }
    ];
    environment.systemPackages = lib.optionals runServer [
      (
        if useStatistics
        then config.services.cliproxyapi.package
        else pkgs.cliproxyapi
      )
    ];

    sops = {
      secrets = {
        "cliproxyapi-public-api-key" = {
          owner = currentSystemUser;
          mode = "0400";
        };
        "cliproxyapi-local-api-key" = lib.mkIf runServer {
          owner = currentSystemUser;
          mode = "0400";
        };
        "opencode-zen-api-key" = lib.mkIf runServer {};
        "cliproxyapi-clickhouse-password" = lib.mkIf useStatistics {};
        "cliproxyapi-clickhouse-admin-password" = lib.mkIf useStatistics {};
      };
      templates = {
        "cliproxyapi-quota.env" = lib.mkIf useStatistics {
          owner = "root";
          mode = "0400";
          restartUnits = ["cliproxyapi.service"];
          content = ''
            CLICKHOUSE_QUOTA_PASSWORD=${config.sops.placeholder."cliproxyapi-clickhouse-password"}
          '';
        };
        "cliproxyapi-clickhouse.env" = lib.mkIf useStatistics {
          owner = "root";
          mode = "0400";
          restartUnits = ["clickhouse.service" "cliproxyapi-quota-schema.service"];
          content = ''
            CLICKHOUSE_QUOTA_PASSWORD=${config.sops.placeholder."cliproxyapi-clickhouse-password"}
            CLICKHOUSE_QUOTA_ADMIN_PASSWORD=${config.sops.placeholder."cliproxyapi-clickhouse-admin-password"}
          '';
        };
        "cliproxyapi.conf" = lib.mkIf runServer {
          owner = currentSystemUser;
          mode = "0400";
          restartUnits = ["cliproxyapi.service"];
          content = cliProxy.mkServerConfig {
            inherit homeDirectory;
            pinnedPanel = useStatistics;
            localApiKey = config.sops.placeholder."cliproxyapi-local-api-key";
            openCodeZenApiKey = config.sops.placeholder."opencode-zen-api-key";
          };
        };
      };
    };

    services.cliproxyapi = lib.mkIf useStatistics {
      enable = true;
      user = currentSystemUser;
      workingDirectory = homeDirectory;
      credentialDirectory = "${homeDirectory}/.cli-proxy-api";
      configFile = config.sops.templates."cliproxyapi.conf".path;
      environmentFile = config.sops.templates."cliproxyapi-quota.env".path;
      localClickHouse = {
        enable = true;
        environmentFile = config.sops.templates."cliproxyapi-clickhouse.env".path;
      };
    };

    # Packaged by Fleet; reads the same credentials CLIProxyAPI writes.
    services.cliproxyapi-quota = lib.mkIf runServer {
      enable = true;
      user = currentSystemUser;
      credentialDirectory = "${homeDirectory}/.cli-proxy-api";
      listenAddress = cliProxy.host;
      port = cliProxy.quotaPort;
    };
    # A broken package or credential directory must surface as a failed unit
    # that HomelabImportantUnitFailed can alert on, so cap restart attempts
    # rather than loop forever. The Fleet module's RestartSec = 5 lets an
    # immediately failing start exhaust this limit within its interval.
    systemd.services.cliproxyapi-quota.unitConfig = lib.mkIf runServer {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 5;
    };

    systemd.services.cliproxyapi = lib.mkIf (runServer && !useStatistics) {
      description = "CLIProxyAPI local AI provider proxy";
      environment.MANAGEMENT_STATIC_PATH = "${homeDirectory}/.local/share/cliproxyapi/static";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      serviceConfig = {
        User = currentSystemUser;
        ExecStart = "${lib.getExe pkgs.cliproxyapi} -config ${config.sops.templates."cliproxyapi.conf".path}";
        Restart = "always";
        RestartSec = 5;
        WorkingDirectory = homeDirectory;
      };
    };
  };
}
