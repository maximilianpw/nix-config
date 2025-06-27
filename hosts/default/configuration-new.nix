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
  networking.hostName = "nixos-default";

  # UEFI boot configuration
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
    discord
    vscode
  ];

  # Additional development packages for this host
  environment.systemPackages = with pkgs; [
    rustup
    vscode
  ];
}
