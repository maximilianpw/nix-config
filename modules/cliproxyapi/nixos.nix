{
  currentSystemUser,
  lib,
  pkgs,
  ...
}: let
  cliProxy = import ./config.nix;
  homeDirectory = "/home/${currentSystemUser}";
in {
  environment = {
    systemPackages = [pkgs.cliproxyapi];
    etc."cliproxyapi.conf".text = cliProxy.mkServerConfig {inherit homeDirectory;};
  };

  systemd.services.cliproxyapi = {
    description = "CLIProxyAPI local AI provider proxy";
    environment.MANAGEMENT_STATIC_PATH = "${homeDirectory}/.local/share/cliproxyapi/static";
    wantedBy = ["multi-user.target"];
    wants = ["network-online.target"];
    after = ["network-online.target"];
    serviceConfig = {
      User = currentSystemUser;
      ExecStart = "${lib.getExe pkgs.cliproxyapi} -config /etc/cliproxyapi.conf";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = homeDirectory;
    };
  };
}
