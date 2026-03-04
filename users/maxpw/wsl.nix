{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../modules/core/nix-settings.nix
    ../../modules/core/security.nix
    ./modules/linux-common.nix
  ];

  users.users.maxpw = {
    isNormalUser = true;
    description = lib.mkDefault "Maximilian PINDER-WHITE";
    extraGroups = ["wheel" "docker"];
    home = "/home/maxpw";
    shell = pkgs.fish;
  };

  system.stateVersion = lib.mkDefault "24.05";
}
