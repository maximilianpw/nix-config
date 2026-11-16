# Daily read-only morning report. Each run writes ~/reports/morning/<date>.md
# (through a temporary file beside it, mode 0600) and a scratch directory it
# removes; everything else is only read, and git runs with optional locks
# disabled.
{
  config,
  homelab,
  lib,
  pkgs,
  ...
}: let
  runReport = config.custom.morningReport.enable;
  reportDirectory = "${config.home.homeDirectory}/reports/morning";
  # Mirrors nodeExporterTextfileDirectory in homelab/monitoring/default.nix and the
  # file written by homelab/monitoring/cliproxyapi-readiness-probe.sh; absence is "unknown".
  readinessFile = "/var/lib/prometheus-node-exporter-text-files/cliproxyapi-readiness.prom";
  morningReport = pkgs.writeShellApplication {
    name = "morning-report";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.gh
      pkgs.git
      pkgs.gnugrep
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      export MORNING_REPORT_DIR=${lib.escapeShellArg reportDirectory}
      export MORNING_REPORT_REPO=${lib.escapeShellArg "${config.home.homeDirectory}/nix-config"}
      export MORNING_REPORT_GITHUB_REPO=maximilianpw/nix-config
      export HOMELAB_IMPORTANT_UNITS=${lib.escapeShellArg (lib.concatStringsSep " " homelab.importantSystemdUnits)}
      export CLIPROXYAPI_READINESS_FILE=${lib.escapeShellArg readinessFile}
      exec ${lib.getExe pkgs.bash} ${./morning-report.sh} "$@"
    '';
  };
in {
  options.custom.morningReport.enable = lib.mkEnableOption "the daily read-only morning report timer";

  config = {
    home.packages = lib.optionals runReport [morningReport];

    systemd.user.services.morning-report = lib.mkIf runReport {
      Unit = {
        Description = "Read-only morning status report";
        After = ["network-online.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe morningReport;
        WorkingDirectory = "%h";
        # cliproxyapi-util is a Home Manager file in ~/.local/bin, not a package.
        Environment = [
          "PATH=${config.home.homeDirectory}/.local/bin:/run/current-system/sw/bin"
        ];
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    systemd.user.timers.morning-report = lib.mkIf runReport {
      Unit.Description = "Daily read-only morning status report";
      Timer = {
        OnCalendar = "*-*-* 07:00:00";
        RandomizedDelaySec = "5m";
        # Catch up after downtime so a missed morning still produces a report.
        Persistent = true;
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
