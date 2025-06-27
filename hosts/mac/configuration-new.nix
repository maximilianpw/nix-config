{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.default
  ];

  # Host-specific configuration
  networking.hostName = "nixos-mac";

  # UEFI boot configuration for ARM64
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      device = "nodev";
      useOSProber = true;
    };
    efi.canTouchEfiVariables = true;
  };

  # Host-specific packages
  users.users.maxpw.packages = with pkgs; [
    firefox
  ];

  # ARM64-specific development packages
  environment.systemPackages = with pkgs; [
    rustup
    vscode
    firefox
  ];
}
