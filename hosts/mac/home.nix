{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/home-manager/dotfiles.nix
  ];

  programs.home-manager.enable = true;

  home.username = "maxpw";
  home.homeDirectory = "/home/maxpw";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    hello
    _1password-cli
    _1password-gui
  ];

  nixpkgs.config.allowUnfree = true;
}
