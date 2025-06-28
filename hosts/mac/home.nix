{
  config,
  pkgs,
  ...
}: {
  imports = [
    ../../modules/home-manager/dotfiles.nix
  ];

  home.username = "maxpw";
  home.homeDirectory = "/home/maxpw";
  home.stateVersion = "23.11";

  home.packages = with pkgs; [
    hello
    _1password_cli
  ];

  programs.home-manager.enable = true;
}
