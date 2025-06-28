{
  config,
  pkgs,
  ...
}: {
  # Terminal and shell configuration module
  # This module only provides packages needed for your .zshrc configuration
  # All configuration is handled by your dotfiles

  home.packages = with pkgs; [
    # Core terminal utilities
    ripgrep
    fd
    fzf
    curl
    wget
    unzip

    # Git and version control
    git
    lazygit

    # Terminal utilities
    tree
    htop
    btop
    bat

    # Zsh plugins and tools (for your .zshrc)
    zoxide # Better cd command
    oh-my-posh # Prompt theme engine

    # Rust toolchain (from your .zshrc)
    rustup

    # Angular CLI (from your .zshrc completions)
    nodejs_20
    nodePackages."@angular/cli"

    # Docker tools (from your .zshrc completions)
    docker
    docker-compose

    # OpenTofu (open source Terraform alternative)
    opentofu
  ];

  # Enable zsh system-wide (minimal setup)
  programs.zsh.enable = true;

  # Create symlink from ~/dotfiles/.zshrc to ~/.zshrc
  # home.file.".zshrc" = {
  # source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.zshrc";
  # };

  # Create symlink from ~/dotfiles/.config to ~/.config
  #home.file.".config" = {
  # source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/.config";
  # };
}
