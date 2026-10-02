# Daily read-only morning report. Writes one Markdown file under the user's
# home and changes nothing else; see docs/agent-tooling-backlog.md.
{
  config,
  hostRecord,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../../../lib/homelab.nix {inherit lib;};
  # Unattended, homelab-aware work is scoped to hosts the inventory marks for
  # long-running agents with the homelab profile; today that is only Kim.
  runReport = hostRecord.longRunningAgents && lib.elem "homelab" hostRecord.profiles;
  reportDirectory = "${config.home.homeDirectory}/reports/morning";
  # Mirrors nodeExporterTextfileDirectory in homelab/monitoring.nix and the
  # file written by scripts/cliproxyapi-readiness-probe.sh; absence is "unknown".
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
      exec ${lib.getExe pkgs.bash} ${../../../scripts/morning-report.sh} "$@"
    '';
  };
in {
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
}
