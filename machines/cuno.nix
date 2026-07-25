{
  lib,
  pkgs,
  ...
}: {
  wsl = {
    enable = true;
    defaultUser = "maxpw";
    startMenuLaunchers = true;
    wslConf.automount.root = "/mnt";
  };

  networking.hostName = "cuno";

  virtualisation.docker.enable = true;
  # Default docker (28.x) is unmaintained and marked insecure in nixpkgs 25.11
  virtualisation.docker.package = pkgs.docker_29;

  system.stateVersion = lib.mkDefault "24.05";
}
