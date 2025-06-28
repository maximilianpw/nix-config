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

  programs.ssh.enable = true;
  programs.ssh.extraConfig = ''
    Host github.com
      IdentityAgent "~/.1password/agent.sock"
  '';

  nixpkgs.config.allowUnfree = true;
}
