{
  config,
  pkgs,
  lib,
  ...
}: {
  # VMware-specific configurations
  imports = [./vm-common.nix];
  
  # VMware-specific optimizations - only for x86_64
  virtualisation.vmware.guest.enable = lib.mkIf (pkgs.stdenv.isx86_64) true;
  
  # VMware display optimizations - only for x86_64
  services.xserver.videoDrivers = lib.mkIf (pkgs.stdenv.isx86_64) ["vmware"];
  
  # Enable vmware tools
  environment.systemPackages = with pkgs; [
    open-vm-tools
  ];
  
  # Disable unnecessary services for VMware
  services.udisks2.enable = lib.mkDefault false;
}