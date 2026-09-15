{
  config,
  currentSystemName,
  currentSystemUser,
  lib,
  pkgs,
  ...
}: let
  cliProxy = import ./config.nix;
  homeDirectory = "/home/${currentSystemUser}";
  runServer = currentSystemName == "kim";
in {
  environment.systemPackages = lib.optionals runServer [pkgs.cliproxyapi];

  sops = {
    secrets = {
      "cliproxyapi-public-api-key" = {
        owner = currentSystemUser;
        mode = "0400";
      };
      "cliproxyapi-local-api-key" = lib.mkIf runServer {
        owner = currentSystemUser;
        mode = "0400";
      };
      "opencode-zen-api-key" = lib.mkIf runServer {};
    };
    templates."cliproxyapi.conf" = lib.mkIf runServer {
      owner = currentSystemUser;
      mode = "0400";
      restartUnits = ["cliproxyapi.service"];
      content = cliProxy.mkServerConfig {
        inherit homeDirectory;
        localApiKey = config.sops.placeholder."cliproxyapi-local-api-key";
        openCodeZenApiKey = config.sops.placeholder."opencode-zen-api-key";
      };
    };
  };

  systemd.services.cliproxyapi = lib.mkIf runServer {
    description = "CLIProxyAPI local AI provider proxy";
    environment.MANAGEMENT_STATIC_PATH = "${homeDirectory}/.local/share/cliproxyapi/static";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    serviceConfig = {
      User = currentSystemUser;
      ExecStart = "${lib.getExe pkgs.cliproxyapi} -config ${config.sops.templates."cliproxyapi.conf".path}";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = homeDirectory;
    };
  };
}
