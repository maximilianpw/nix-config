{
  config,
  pkgs,
  ...
}: {
  # Development tools and programming languages module
  # This module provides compilers, runtimes, and development utilities
  # Enhanced with packages from your .zshrc and nvim configuration

  home.packages = with pkgs; [
    # Programming language runtimes (ARM64 compatible)
    nodejs_20
    python3
    python311Packages.pip
    rustup
    go
    openjdk

    # Node.js development tools (from your .zshrc Angular CLI)
    nodePackages."@angular/cli"
    yarn
    pnpm

    # Build tools and compilers (moved to system-level common.nix)
    # gcc, clang, gnumake, cmake are now system packages

    # Additional development utilities
    jq

    # Container and deployment tools (from your .zshrc Docker completions)
    docker
    docker-compose

    # Version control tools (from your .zshrc)
    git

    # Infrastructure tools (from your .zshrc zinit snippets)
    opentofu # Open source Terraform alternative
    awscli2 # AWS CLI from your .zshrc oh-my-zsh plugins

    # Java development tools
    maven
    gradle
  ];

  # Development-specific session variables moved to dotfiles
  # All environment variables should be set in your .zshrc or shell config files
  # This avoids conflicts with the .config symlink approach

  # Create useful development directories
  home.file = {
    # Create development workspace structure
    "Development/.keep".text = "";
    "go/bin/.keep".text = "";
    "go/pkg/.keep".text = "";
    "go/src/.keep".text = "";

    # Note: Configuration files like ripgrep config are handled by dotfiles symlink
  };
}
