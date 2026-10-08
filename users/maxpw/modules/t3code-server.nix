{
  config,
  hostname,
  isLinuxDesktop,
  pkgs,
  lib,
  ...
}: let
  # Run headlessly on Linux desktops and Kim, where Tailscale Serve provides
  # tailnet-only HTTPS.
  runServer = isLinuxDesktop || hostname == "kim";
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
      ExecStart = "${pkgs.t3code}/bin/t3 serve --host 127.0.0.1 --port 51000 --base-dir %h/.local/share/t3code --no-browser";
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
