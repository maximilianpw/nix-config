{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
    ../../modules/nixos/common.nix
    ../../modules/nixos/vm-common.nix
    # ../../modules/nixos/vmware.nix  # Only if you have ARM64-safe tweaks
  ];

  # VMware Fusion ARM64 kernel optimizations
  boot.kernelParams = [
    "elevator=mq-deadline"
    "transparent_hugepage=madvise"
    "mitigations=auto"
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
    useOSProber = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";

  # Prefer explicit over global DHCP
  networking.interfaces.ens160.useDHCP = true;

  users.users.maxpw = {
    description = "Maximilian Pinder-White";
    packages = with pkgs; [firefox];
  };

  home-manager = {
    extraSpecialArgs = {inherit inputs;};
    users = {
      "maxpw" = import ./home.nix;
    };
  };

  environment.systemPackages = with pkgs; [
    open-vm-tools
    git
    neofetch
  ];

  # VMware guest modules not available on ARM64
  virtualisation.vmware.guest.enable = false;

  system.stateVersion = "24.05";
}
