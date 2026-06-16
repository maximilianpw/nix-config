{
  currentSystemUser,
  pkgs,
  ...
}: let
  home = "/home/${currentSystemUser}";
in {
  environment.systemPackages = [
    pkgs.hermes
  ];

  systemd.services.hermes-agent = {
    description = "Hermes Agent gateway and cron scheduler";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];

    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.openssh
      pkgs.ripgrep
    ];

    environment = {
      HOME = home;
      HERMES_HOME = "${home}/.hermes";
      HERMES_MANAGED = "true";
      HERMES_ACCEPT_HOOKS = "1";
      MESSAGING_CWD = home;
    };

    serviceConfig = {
      Type = "simple";
      User = currentSystemUser;
      WorkingDirectory = home;
      ExecStart = "${pkgs.hermes}/bin/hermes gateway run --replace";
      Restart = "always";
      RestartSec = 10;
      PrivateTmp = true;
    };
  };
}
