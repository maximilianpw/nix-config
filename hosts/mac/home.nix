{
  config,
  pkgs,
  ...
}: {
  # Import the global dotfiles configuration
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
    # Add any user-specific packages here that aren't in the global config
  ];

  # User-specific program overrides
  programs = {
    # Override git configuration with user-specific settings
    git = {
      userName = "Maximilian Pinder-White";
      userEmail = "your-email@example.com"; # Replace with your email
      # Global git config from dotfiles.nix is automatically merged
    };

    # You can override or extend any program configuration from dotfiles.nix here
    # For example, add user-specific zsh configuration:
    zsh = {
      shellAliases = {
        # User-specific aliases
        ll = "ls -la";
        la = "ls -A";
        l = "ls -CF";
      };
      # Global zsh config from dotfiles.nix is automatically merged
    };
  };

  # User-specific session variables (in addition to global ones)
  home.sessionVariables = {
    # Add any user-specific environment variables here
    # Global variables from dotfiles.nix are automatically merged
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
