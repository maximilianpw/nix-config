{
  config,
  pkgs,
  ...
}: {
  # Development tools and programming languages module
  # This module provides compilers, runtimes, and development utilities
  
  home.packages = with pkgs; [
    # Programming language runtimes (ARM64 compatible)
    nodejs_20
    python3
    python311Packages.pip
    rustup
    go
    openjdk

    # Node.js development tools
    nodePackages."@angular/cli"
    yarn
    pnpm

    # Build tools and compilers (ARM64 compatible)
    gnumake
    cmake
    gcc
    clang
    
    # Additional development utilities
    jq
    yq
    
    # Container and deployment tools
    docker-compose
    
    # API testing
    httpie
    
    # Database tools
    sqlite
    
    # Documentation tools
    pandoc
  ];

  # Development-specific session variables
  home.sessionVariables = {
    # Java setup
    JAVA_HOME = "${pkgs.openjdk}";
    
    # Node.js settings
    NODE_OPTIONS = "--max-old-space-size=4096";
    
    # Python settings
    PYTHONPATH = "$HOME/.local/lib/python3.11/site-packages:$PYTHONPATH";
    
    # Rust setup
    CARGO_HOME = "$HOME/.cargo";
    RUSTUP_HOME = "$HOME/.rustup";
    
    # Go setup
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
    
    # Development PATH additions
    PATH = "$PATH:$HOME/.cargo/bin:$HOME/go/bin:$HOME/.local/bin";
  };

  # Development-specific programs
  programs = {
    # Direnv is already configured in terminal.nix, but we can add dev-specific templates
    direnv = {
      stdlib = ''
        # Custom layouts for different project types
        layout_poetry() {
          if [[ ! -f pyproject.toml ]]; then
            log_error 'No pyproject.toml found. Use `poetry init` to create one first.'
            exit 2
          fi
          
          local VENV=$(poetry env list --full-path | cut -d' ' -f1)
          if [[ -z $VENV || ! -d $VENV ]]; then
            log_status 'No poetry virtual environment found. Use `poetry install` to create one first.'
            exit 2
          fi
          
          export VIRTUAL_ENV=$VENV
          PATH_add "$VENV/bin"
        }
        
        layout_node() {
          local NODE_VERSION="20"
          if [[ -f .nvmrc ]]; then
            NODE_VERSION=$(cat .nvmrc)
          fi
          echo "Using Node.js version: $NODE_VERSION"
          PATH_add node_modules/.bin
        }
      '';
    };
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
