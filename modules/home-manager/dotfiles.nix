{
  config,
  pkgs,
  ...
}: {
  # Main dotfiles configuration - imports all specialized modules
  # This provides a comprehensive development environment
  
  imports = [
    ./neovim.nix      # Neovim editor configuration
    ./terminal.nix    # Terminal and shell configuration  
    ./development.nix # Programming languages and dev tools
    ./fonts.nix       # Font management
  ];

  # Allow Home Manager to manage itself
  programs.home-manager.enable = true;

  # Essential user packages
  home.packages = with pkgs; [
    # Rebuild script for convenience
    (writeShellScriptBin "rebuild" (builtins.readFile ../../scripts/nixos-rebuild.sh))
  ];

  # This file now serves as the main entry point that combines all modules
  # Individual modules can be imported separately if needed
}