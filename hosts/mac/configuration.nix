{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    # Import shared system configuration
    ../../modules/nixos/common.nix
    ../../modules/nixos/vm-common.nix
    # ../../modules/nixos/vmware.nix  # Disabled for ARM64
  ];

  # VMware Fusion specific configuration for ARM64
  # Note: Traditional VMware guest tools are not available on ARM64
  # Using open-vm-tools package instead (defined in systemPackages)

  # VMware Fusion ARM optimizations for Linux LTS
  boot.kernelParams = [
    "elevator=mq-deadline" # Better I/O scheduler for modern kernels on ARM64
    "transparent_hugepage=madvise" # More conservative memory management for ARM64
    # "clocksource=tsc"      # TSC may not be available on ARM64, let kernel choose
    "mitigations=auto" # Enable security mitigations appropriate for platform
  ];

  # Bootloader.
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev"; # Indicates not to install to a specific device, as it's UEFI
    useOSProber = true; # To detect other OSes like Windows
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos"; # Define your hostname.

  # VMware network optimizations
  networking.interfaces = {
    # VMware typically uses ens160 or similar
    ens160.useDHCP = true;
  };

  # Mac-specific user overrides
  users.users.maxpw = {
    description = "Maximilian Pinder-White";
    packages = with pkgs; [
      firefox
    ];
  };

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    users = {
      "maxpw" = import ./home.nix;
    };
  };

  # Mac-specific system packages (minimal set, others handled by modules)
  environment.systemPackages = with pkgs; [
    # VMware Fusion specific tools (ARM64 compatible)
    open-vm-tools
    # Essential system tools
    git
    neofetch
  ];

  # ARM64-specific VMware configuration
  # Note: Traditional VMware guest tools are not available on ARM64
  # Disable VMware guest modules that are x86-only
  virtualisation.vmware.guest.enable = false;

  # System state version - host specific
  system.stateVersion = "23.11"; # Did you read the comment?
}
