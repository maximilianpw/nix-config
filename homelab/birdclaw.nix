{
  currentSystemUser,
  pkgs,
  ...
}: let
  home = "/home/${currentSystemUser}";
  dataDir = "/srv/birdclaw";
  envFile = "${dataDir}/bird.env";
  runtimeConfigFile = "${dataDir}/config.json";
  port = "3003";
  configFile = pkgs.writeText "birdclaw-config.json" ''
    {
      "actions": {
        "transport": "auto"
      },
      "mentions": {
        "dataSource": "bird",
        "birdCommand": "${pkgs.bird}/bin/bird"
      }
    }
  '';
in {
  environment.systemPackages = [
    pkgs.bird
    pkgs.birdclaw
    pkgs.xurl
  ];

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0700 ${currentSystemUser} users - -"
    "C ${runtimeConfigFile} 0600 ${currentSystemUser} users - ${configFile}"
    "f ${envFile} 0600 ${currentSystemUser} users - -"
  ];

  systemd.services.birdclaw = {
    description = "Birdclaw local Twitter memory";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];

    path = [
      pkgs.bird
      pkgs.xurl
    ];

    environment = {
      HOME = home;
      BIRDCLAW_CONFIG = runtimeConfigFile;
      BIRDCLAW_HOME = dataDir;
      BIRDCLAW_ALLOW_REMOTE_WEB = "1";
      BIRDCLAW_BIRD_COMMAND = "${pkgs.bird}/bin/bird";
      BIRDCLAW_HOST = "127.0.0.1";
      BIRDCLAW_PORT = port;
    };

    serviceConfig = {
      Type = "simple";
      User = currentSystemUser;
      WorkingDirectory = dataDir;
      EnvironmentFile = "-${envFile}";
      ExecStart = "${pkgs.birdclaw}/bin/birdclaw serve";
      Restart = "always";
      RestartSec = 10;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };
}
