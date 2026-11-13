{
  config,
  hostRecord,
  pkgs,
  lib,
  ...
}: let
  # Hosts with a T3 Code port run the server headlessly; on Kim, Tailscale
  # Serve provides tailnet-only HTTPS.
  port = hostRecord.t3codePort;
  runServer = port != null;
  servicePath = [
    pkgs.nodejs
    pkgs.claude-code
    pkgs.codex
    pkgs.opencode
    pkgs.grok
    pkgs.git
    pkgs.openssh

    # T3 probes $SHELL with POSIX syntax; use Bash instead of the login Nu shell.
    pkgs.bash
    pkgs.mise
    pkgs.zoxide
  ];
in {
  home.packages = lib.optionals runServer [
    pkgs.t3code
  ];

  systemd.user.services.t3code = lib.mkIf runServer {
    Unit = {
      Description = "T3 Code headless server";
      After = ["network-online.target"];
    };

    Service = {
      ExecStart = "${pkgs.t3code}/bin/t3 serve --host 127.0.0.1 --port ${toString port} --base-dir %h/.local/share/t3code --no-browser";
      Restart = "on-failure";
      RestartSec = "5s";
      StandardOutput = "journal";
      StandardError = "journal";
      WorkingDirectory = "%h";
      Environment = [
        "PATH=${config.home.homeDirectory}/.local/bin:/run/current-system/sw/bin:${lib.makeBinPath servicePath}"
        "SHELL=${pkgs.bash}/bin/bash"
      ];
    };

    Install.WantedBy = ["default.target"];
  };
}
