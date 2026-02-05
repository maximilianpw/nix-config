{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../modules/core/nix-settings.nix
    ../modules/core/security.nix
  ];

  wsl = {
    enable = true;
    defaultUser = "maxpw";
    startMenuLaunchers = true;
    wslConf.automount.root = "/mnt";
  };

  networking.hostName = "wsl";

  virtualisation.docker.enable = true;

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
