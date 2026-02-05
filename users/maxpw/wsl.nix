{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../../modules/core/nix-settings.nix
    ../../modules/core/security.nix
  ];

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  i18n.extraLocaleSettings = lib.mkDefault {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  users.users.maxpw = {
    isNormalUser = true;
    description = lib.mkDefault "Maximilian PINDER-WHITE";
    extraGroups = ["wheel" "docker"];
    home = "/home/maxpw";
    shell = pkgs.fish;
  };

  programs.fish.enable = true;

  programs.nix-ld = {
    enable = true;
    libraries = [
      pkgs.stdenv.cc.cc
      pkgs.zlib
      pkgs.fuse3
      pkgs.icu
      pkgs.nss
      pkgs.openssl
      pkgs.curl
      pkgs.expat
    ];
  };

  programs.command-not-found.enable = false;

  system.stateVersion = lib.mkDefault "24.05";
}
