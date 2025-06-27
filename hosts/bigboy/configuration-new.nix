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
  networking.hostName = "nixos-bigboy";

  # Legacy BIOS boot configuration
  boot.loader = {
    grub = {
      enable = true;
      device = "/dev/sda";
      useOSProber = true;
    };
  };

  # Host-specific packages for development/gaming
  users.users.maxpw.packages = with pkgs; [
    firefox
    steam
    discord
    obs-studio
  ];

  # Gaming and development packages
  environment.systemPackages = with pkgs; [
    rustup
    steam-run
  ];

  # Enable Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };
}
