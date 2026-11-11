{lib, ...}: {
  wsl = {
    enable = true;
    defaultUser = "maxpw";
    startMenuLaunchers = true;
    wslConf.automount.root = "/mnt";
  };

  networking.hostName = "cuno";

  virtualisation.docker.enable = true;

  system.stateVersion = lib.mkDefault "24.05";
}
