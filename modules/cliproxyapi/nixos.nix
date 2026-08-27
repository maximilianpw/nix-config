{
  config,
  currentSystemUser,
  lib,
  pkgs,
  ...
}: let
  cliProxy = import ./config.nix;
  homeDirectory = "/home/${currentSystemUser}";
in {
  environment.systemPackages = [pkgs.cliproxyapi];

  sops = {
    secrets."opencode-zen-api-key" = {};
    templates."cliproxyapi.conf" = {
      owner = currentSystemUser;
      mode = "0400";
      restartUnits = ["cliproxyapi.service"];
      content = cliProxy.mkServerConfig {
        inherit homeDirectory;
        openCodeZenApiKey = config.sops.placeholder."opencode-zen-api-key";
      };
    };
  };

  systemd.services.cliproxyapi = {
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
