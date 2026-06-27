{
  isLinuxDesktop,
  pkgs,
  lib,
  ...
}: {
  home.packages = lib.optionals isLinuxDesktop [
    pkgs.nodejs
  ];

  systemd.user.services.t3code = lib.mkIf isLinuxDesktop {
    Unit = {
      Description = "T3 Code headless server";
      After = ["network-online.target"];
    };

    Service = {
      ExecStart = "${pkgs.nodejs}/bin/npx --yes t3@0.0.27 serve --host 127.0.0.1 --port 51000 --base-dir %h/.local/share/t3code --no-browser";
      Restart = "on-failure";
      RestartSec = "5s";
      WorkingDirectory = "%h";
      Environment = [
        "PATH=%h/.nix-profile/bin:/run/current-system/sw/bin:${lib.makeBinPath [
          pkgs.nodejs
          pkgs.claude-code
          pkgs.codex
          pkgs.opencode
          pkgs.git
          pkgs.openssh
        ]}"
      ];
    };

    Install.WantedBy = ["default.target"];
  };
}
