{
  config,
  pkgs,
  lib,
  ...
}: {
  # VM-specific optimizations and configurations
  
  # VM Performance optimizations
  boot.kernelParams = [
    "elevator=mq-deadline"           # Better I/O scheduler for VMs
    "transparent_hugepage=madvise"   # Conservative memory management
    "mitigations=auto"               # Security mitigations
    "quiet"                          # Reduce boot noise
    "splash"                         # Boot splash screen
  ];
  
  # Enable QEMU guest agent for better VM integration
  services.qemuGuest.enable = lib.mkDefault true;
  
  # VM-specific network optimizations
  networking.useDHCP = lib.mkForce false;
  networking.interfaces = lib.mkDefault {};
  
  # Faster boot for VMs
  boot.loader.timeout = lib.mkDefault 1;
  
  # VM-specific services
  services = {
    # Enable SSH for remote management
    openssh = {
      enable = lib.mkDefault true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    
    # Disable unused services in VMs
    logind.lidSwitch = lib.mkDefault "ignore";
    logind.lidSwitchDocked = lib.mkDefault "ignore";
  };
  
  # VM-specific hardware optimizations
  hardware = {
    enableRedistributableFirmware = lib.mkDefault true;
    cpu.intel.updateMicrocode = lib.mkDefault true;
    cpu.amd.updateMicrocode = lib.mkDefault true;
  };
  
  # Filesystem optimizations for VMs
  services.fstrim.enable = true;
  
  # VM memory management
  systemd.services.nix-daemon.serviceConfig.OOMScoreAdjust = 250;
  
  # Reduce journal size for VMs
  services.journald.settings = {
    SystemMaxUse = "100M";
    RuntimeMaxUse = "50M";
  };
  
  # VM-specific font configuration
  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
      (nerdfonts.override {fonts = ["FiraCode" "JetBrainsMono" "Hack"];})
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = ["Noto Serif"];
        sansSerif = ["Noto Sans"];
        monospace = ["FiraCode Nerd Font"];
      };
    };
  };
}
