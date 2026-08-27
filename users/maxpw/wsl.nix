{
  pkgs,
  lib,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
in {
  imports = [
    ../../modules/cliproxyapi/nixos.nix
    ../../modules/core/nix-settings.nix
    ../../modules/core/sops-user-key.nix
    ../../modules/core/security.nix
    ../../modules/core/shells.nix
    ../../modules/fleet/nixos.nix
    ../../modules/fleet/ssh-access.nix
    ./modules/linux-common.nix
  ];

  users.users.maxpw = {
    isNormalUser = true;
    description = lib.mkDefault "Maximilian PINDER-WHITE";
    extraGroups = ["wheel" "docker"];
    home = "/home/maxpw";
    shell = settings.loginShell;
  };

  system.stateVersion = lib.mkDefault "24.05";
}
