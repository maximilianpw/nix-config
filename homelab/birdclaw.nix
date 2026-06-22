{
  currentSystemUser,
  pkgs,
  ...
}: let
  home = "/home/${currentSystemUser}";
  dataDir = "/srv/birdclaw";
  port = "3003";
in {
  environment.systemPackages = [
    pkgs.birdclaw
  ];

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0700 ${currentSystemUser} users - -"
  ];

  systemd.services.birdclaw = {
    description = "Birdclaw local Twitter memory";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];

    environment = {
      HOME = home;
      BIRDCLAW_HOME = dataDir;
      BIRDCLAW_ALLOW_REMOTE_WEB = "1";
      BIRDCLAW_HOST = "127.0.0.1";
      BIRDCLAW_PORT = port;
    };

    serviceConfig = {
      Type = "simple";
      User = currentSystemUser;
      WorkingDirectory = dataDir;
      ExecStart = "${pkgs.birdclaw}/bin/birdclaw serve";
      Restart = "always";
      RestartSec = 10;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
