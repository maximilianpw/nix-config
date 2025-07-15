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

  # home.shellAlias = {
  #    rebuild = "/home/maxpw/Nix-Config/scripts/nixos-rebuild.sh mac";
  #  };

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    xwayland.enable = true;
  };
}
