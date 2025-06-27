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
    opentofu  # Open source Terraform alternative
    awscli2   # AWS CLI from your .zshrc oh-my-zsh plugins
    
    # Java development tools
    maven
    gradle
  ];

  # Development-specific session variables
  home.sessionVariables = {
    # Java setup
    JAVA_HOME = "${pkgs.openjdk}";
    
    # Rust setup
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
    
    # Node.js setup
    NODE_PATH = "${pkgs.nodejs_20}/lib/node_modules";
    NODE_OPTIONS = "--max-old-space-size=4096";
    
    # Go setup
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
    
    # Python setup
    PYTHONPATH = "$HOME/.local/lib/python3.11/site-packages";
    
    # Development tools
    BROWSER = "firefox";
    
    # Development PATH additions
    PATH = "$PATH:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.local/bin";
  };
  
  # Create useful development directories
  home.file = {
    # Create development workspace structure
    "Development/.keep".text = "";
    "go/bin/.keep".text = "";
    "go/pkg/.keep".text = "";
    "go/src/.keep".text = "";
    
    # Ripgrep configuration
    ".config/ripgrep/config".text = ''
      # Don't search in git directories
      --glob=!.git/*
      
      # Don't search in node_modules
      --glob=!node_modules/*
      
      # Don't search in build directories
      --glob=!build/*
      --glob=!dist/*
      --glob=!target/*
      
      # Use smart case
      --smart-case
      
      # Show line numbers
      --line-number
      
      # Show colors
      --color=always
    '';
  };
}
