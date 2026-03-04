{lib, ...}: {
  wsl = {
    enable = true;
    defaultUser = "maxpw";
    startMenuLaunchers = true;
    wslConf.automount.root = "/mnt";
  };

  networking.hostName = "wsl";

  virtualisation.docker.enable = true;

  # Disable SSH daemon inside WSL by default.
  services.openssh.enable = lib.mkForce false;

  system.stateVersion = lib.mkDefault "24.05";
}
