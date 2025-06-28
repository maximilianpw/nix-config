{
  config,
  pkgs,
  ...
}: {
  # Main dotfiles configuration - imports all home-manager modules
  # Build tools are provided system-wide to avoid package conflicts

  imports = [
    ./terminal.nix # Terminal tools and utilities
    ./neovim.nix # Language servers and Neovim tools
    ./development.nix # Development tools and runtimes
#    ./fonts.nix # Font packages
  ];

  # Create symlinks to dotfiles
#home.file = {
    # Symlink entire .config directory to dotfiles
 #  ".config/nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config/nvim";

    # Symlink shell configuration
  # ".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.zshrc";
 #};
}
