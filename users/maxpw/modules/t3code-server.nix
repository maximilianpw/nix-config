{
  hostname,
  isLinuxDesktop,
  pkgs,
  lib,
  ...
}: let
  # The server itself is headless: run it on Linux desktops and on the
  # main-pc homelab box, where Tailscale Serve provides tailnet-only HTTPS.
  runServer = isLinuxDesktop || hostname == "main-pc";
  t3Version = "0.0.28";
  servicePath =
    [
      pkgs.nodejs
      pkgs.claude-code
      pkgs.codex
      pkgs.opencode
      pkgs.grok
      pkgs.git
      pkgs.openssh

      # T3 probes $SHELL with POSIX syntax; use zsh instead of the login Nu shell.
      pkgs.zsh
      pkgs.bash
      pkgs.mise
      pkgs.zoxide
    ]
    ++ [
      # node-pty has no prebuild for this Node runtime and falls back to node-gyp.
      pkgs.gcc
      pkgs.gnumake
      pkgs.python3
    ];
in {
  home.packages = lib.optionals runServer [
    pkgs.nodejs
  ];

  systemd.user.services.t3code = lib.mkIf runServer {
    Unit = {
      Description = "T3 Code headless server";
      After = ["network-online.target"];
    };

    Service = {
      ExecStart = "${pkgs.nodejs}/bin/npx --yes t3@${t3Version} serve --host 127.0.0.1 --port 51000 --base-dir %h/.local/share/t3code --no-browser";
      Restart = "on-failure";
      RestartSec = "5s";
      StandardOutput = "journal";
      StandardError = "journal";
      WorkingDirectory = "%h";
      Environment = [
        "PATH=/run/current-system/sw/bin:${lib.makeBinPath servicePath}"
        "SHELL=${pkgs.zsh}/bin/zsh"
      ];
    };

    Install.WantedBy = ["default.target"];
  };
}
