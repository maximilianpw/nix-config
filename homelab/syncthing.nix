{
  config,
  currentSystemUser,
  lib,
  ...
}: let
  homelab = import ../lib/homelab.nix {inherit lib;};
  home = "/home/${currentSystemUser}";
  inherit (homelab.privateServices) syncthing;
in {
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
    openDefaultPorts = true;
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
