{
  pkgs,
  lib,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
in {
  imports = [
    ../../modules/cliproxyapi/nixos.nix
    ../../modules/nixos/nix-settings.nix
    ../../modules/core/sops-user-key.nix
    ../../modules/core/security.nix
    ../../modules/core/shells.nix
    ../../modules/fleet/nixos.nix
    ../../modules/fleet/system.nix
    ../../modules/nixos/linux-base.nix
  ];

  users.users.maxpw = {
    isNormalUser = true;
    description = lib.mkDefault "Maximilian PINDER-WHITE";
    extraGroups = ["wheel" "docker"];
    home = "/home/maxpw";
    shell = settings.loginShell;
  };
}
