{
  config,
  currentSystemUser,
  lib,
  ...
}: let
  homelab = import ./inventory {inherit lib;};
  home = "/home/${currentSystemUser}";
  inherit (homelab.privateServices) syncthing;
in {
  custom.backup.applicationVersions.syncthing = config.services.syncthing.package.version;

  networking.firewall.interfaces = lib.genAttrs ["enp194s0" "tailscale0"] (_: {
    allowedTCPPorts = [22000];
    allowedUDPPorts = [22000 21027];
  });

  sops.secrets.syncthing-gui-password = {
    owner = currentSystemUser;
    restartUnits = ["syncthing-init.service"];
  };

  services.syncthing = {
    enable = true;
    user = currentSystemUser;
    group = "users";
    dataDir = home;
    configDir = "${home}/.config/syncthing";
    guiAddress = "127.0.0.1:${toString syncthing.port}";
    guiPasswordFile = config.sops.secrets.syncthing-gui-password.path;
    overrideDevices = false;
    overrideFolders = false;
    settings = {
      gui = {
        user = currentSystemUser;
        theme = "black";
        # Reached through Tailscale Serve, which forwards a non-localhost Host
        # header; skip Syncthing's host check so it doesn't reject those.
        insecureSkipHostcheck = true;
      };
      options = {
        localAnnounceEnabled = true;
        # Keep Syncthing from asking the router for a UPnP/NAT-PMP port forward.
        natEnabled = false;
        relaysEnabled = true;
        urAccepted = -1;
      };
      folders = {
        "${home}/Sync" = {
          id = "sync";
          label = "Sync";
          path = "${home}/Sync";
          devices = [];
          versioning = {
            type = "trashcan";
            params.cleanoutDays = "30";
          };
        };
      };
    };
  };
}
