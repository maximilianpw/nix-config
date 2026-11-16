{lib, ...}: {
  wsl = {
    enable = true;
    defaultUser = "maxpw";
    startMenuLaunchers = true;
    wslConf.automount.root = "/mnt";
  };

  networking.hostName = "cuno";

  virtualisation.docker.enable = true;
  users.users.maxpw.extraGroups = ["docker"];

  system.stateVersion = lib.mkDefault "24.05";
}
