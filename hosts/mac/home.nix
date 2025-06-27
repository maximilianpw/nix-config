{
  config,
  pkgs,
  ...
}: {
  # Import the global dotfiles configuration (includes all modules)
  imports = [
    ../../modules/home-manager/dotfiles.nix
  ];

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "maxpw";
  home.homeDirectory = "/home/maxpw";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  home.stateVersion = "23.11"; # Please read the comment before changing.

  # User-specific packages (in addition to global ones)
  home.packages = [
    pkgs.hello
    # Add any host-specific packages here
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
