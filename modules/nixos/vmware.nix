{
  config,
  pkgs,
  lib,
  ...
}: {
  # VMware Fusion specific optimizations for ARM64 Macs
  
  imports = [./vm-common.nix];
  
  # VMware-specific boot parameters
  boot.kernelParams = [
    "vmware-vmblock-fuse.enable_vmblock=y"  # VMware shared folders
  ];
  
  # VMware guest services
  services.vmwareGuest = {
    enable = true;
    headless = false;
  };
  
  # VMware network configuration
  networking.interfaces.ens160.useDHCP = lib.mkDefault true;
  
  # VMware graphics optimization for ARM64
  services.xserver.videoDrivers = ["vmware" "fbdev" "vesa"];
  
  # Hardware acceleration for VMware
  hardware.opengl = {
    enable = true;
    driSupport = true;
    # ARM64 doesn't need 32-bit support
  };
  
  # VMware-specific packages
  environment.systemPackages = with pkgs; [
    open-vm-tools
  ];
  
  # VMware time synchronization
  services.timesyncd.enable = false; # Use VMware tools instead
  
  # VMware clipboard and drag-drop
  services.vmwareGuest.enable = true;
  
  # Disable 32-bit ALSA support on ARM64
  services.pipewire.alsa.support32Bit = lib.mkForce false;
}
