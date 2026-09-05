{
  config,
  lib,
  pkgs,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  inherit (homelab.privateServices) kuma;
  reconcileMonitors = pkgs.writeShellApplication {
    name = "uptime-kuma-reconcile";
    runtimeInputs = [pkgs.coreutils pkgs.sqlite];
    text = ''
      export SQLITE_BIN=${lib.getExe pkgs.sqlite}
      exec ${lib.getExe pkgs.bash} ${../scripts/uptime-kuma-reconcile.sh}
    '';
  };
in {
  custom.backup.applicationVersions = {
    kuma = config.services.uptime-kuma.package.version;
    # Preserve the schema-v1 manifest key alongside the canonical service name.
    uptimeKuma = config.services.uptime-kuma.package.version;
  };

  services.uptime-kuma = {
    enable = true;
    appriseSupport = true;
    settings = {
      HOST = "127.0.0.1";
      PORT = toString kuma.port;
    };
  };

  systemd.services.uptime-kuma.serviceConfig.ExecStartPre = [
    (lib.getExe reconcileMonitors)
  ];
}
