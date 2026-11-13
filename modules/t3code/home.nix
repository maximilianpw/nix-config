{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.custom.t3code.server;
  inherit (cfg) port;
  runServer = cfg.enable;
  servicePath = [
    pkgs.nodejs
    pkgs.claude-code
    pkgs.codex
    pkgs.opencode2
    pkgs.grok
    pkgs.git
    pkgs.openssh

    # T3 probes $SHELL with POSIX syntax; use Bash instead of the login Nu shell.
    pkgs.bash
    pkgs.mise
    pkgs.zoxide
  ];
in {
  options.custom.t3code.server = {
    enable = lib.mkEnableOption "the headless T3 Code server (on Kim, Tailscale Serve adds tailnet-only HTTPS)";
    port = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = "Loopback port the server listens on.";
    };
  };

  config = {
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
  };
}
