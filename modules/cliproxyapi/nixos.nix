{
  config,
  currentSystemUser,
  lib,
  pkgs,
  ...
}: let
  homeDirectory = "/home/${currentSystemUser}";
in {
  imports = [(import ./sops.nix {inherit homeDirectory;})];

  environment.systemPackages = [pkgs.cliproxyapi];

  sops.templates."cliproxyapi.conf".restartUnits = ["cliproxyapi.service"];

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
