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
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    hello
    _1password
    _1password-gui
  ];

  nixpkgs.config.allowUnfree = true;
}
