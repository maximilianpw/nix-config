{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [./vm-common.nix];
  virtualisation.vmware.guest.enable = lib.mkIf (pkgs.stdenv.isx86_64) true;
  services.xserver.videoDrivers = lib.mkIf (pkgs.stdenv.isx86_64) ["vmware"];
  environment.systemPackages = with pkgs; [open-vm-tools];
  services.udisks2.enable = lib.mkDefault false;
}
