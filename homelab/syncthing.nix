{
  config,
  currentSystemUser,
  ...
}: let
  home = "/home/${currentSystemUser}";
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
    guiAddress = "127.0.0.1:8384";
    guiPasswordFile = config.sops.secrets.syncthing-gui-password.path;
    openDefaultPorts = true;
    overrideDevices = false;
    overrideFolders = false;
    settings = {
      gui = {
        user = currentSystemUser;
        theme = "black";
        # Reached only via the Cloudflare tunnel, which forwards a non-localhost
        # Host header; skip Syncthing's host check so it doesn't reject those.
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
        "${home}/.hermes" = {
          id = "hermes";
          label = "Hermes";
          path = "${home}/.hermes";
          devices = [];
          ignorePatterns = [
            ".env"
            "auth.json"
            "*.db-wal"
            "*.db-shm"
          ];
          versioning = {
            type = "trashcan";
            params.cleanoutDays = "30";
          };
        };
      };
    };
  };
}
