{
  config,
  pkgs,
  ...
}: {
  # Terminal and shell configuration module
  # This module provides a comprehensive terminal setup with Zsh, utilities, and prompt
  
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
    exa
    
    # Network tools
    nmap
    wget
    curl
  ];

  # Programs configuration
  programs = {
    # Git configuration (global defaults)
    git = {
      enable = true;
      # Add global git aliases and config here
      userName = "Maximilian NixOS";
      userEmail = "mpinderwhite@proton.me";
      aliases = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        df = "diff";
        lg = "log --oneline --graph --all";
        unstage = "reset HEAD --";
        last = "log -1 HEAD";
        visual = "!gitk";
      };
      extraConfig = {
        init = {
          defaultBranch = "main";
        };
        core = {
          editor = "nvim";
        };
        pull = {
          rebase = false;
        };
      };
    };

    # Zsh configuration
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      
      # Shell aliases
      shellAliases = {
        ll = "exa -la";
        la = "exa -a";
        ls = "exa";
        cat = "bat";
        grep = "rg";
        find = "fd";
        tree = "exa --tree";
        # Git aliases
        gs = "git status";
        ga = "git add";
        gc = "git commit";
        gp = "git push";
        gl = "git pull";
        gd = "git diff";
        # System aliases
        rebuild = "sudo nixos-rebuild switch --flake .";
        update = "nix flake update";
      };
      
      # Oh My Zsh configuration
      oh-my-zsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = [ 
          "git" 
          "sudo" 
          "docker" 
          "kubectl" 
          "rust"
          "node"
          "python"
        ];
      };
      
      # Additional Zsh configuration
      initExtra = ''
        # Custom prompt additions
        export PROMPT_EOL_MARK=""
        
        # Better history
        export HISTSIZE=10000
        export SAVEHIST=10000
        setopt HIST_VERIFY
        setopt HIST_IGNORE_ALL_DUPS
        setopt HIST_IGNORE_SPACE
        
        # Auto-completion improvements
        zstyle ':completion:*' menu select
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      '';
    };

    # Zoxide for better cd
    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [
        "--cmd cd"
      ];
    };

    # Direnv for project-specific environments
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    # Starship prompt
    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        format = "$all$character";
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
        git_branch = {
          symbol = "🌱 ";
          format = "[$symbol$branch]($style) ";
        };
        git_status = {
          format = "([\\[$all_status$ahead_behind\\]]($style) )";
        };
        nodejs = {
          symbol = "⬢ ";
        };
        python = {
          symbol = "🐍 ";
        };
        rust = {
          symbol = "🦀 ";
        };
      };
    };

    # Bat configuration (better cat)
    bat = {
      enable = true;
      config = {
        theme = "gruvbox-dark";
        style = "numbers,changes,header";
      };
    };

    # Exa configuration (better ls)
    exa = {
      enable = true;
      enableAliases = true;
    };
  };

  # Terminal-specific session variables
  home.sessionVariables = {
    # Pager settings
    PAGER = "less";
    LESS = "-R";
    
    # FZF settings
    FZF_DEFAULT_COMMAND = "fd --type f --hidden --follow --exclude .git";
    FZF_CTRL_T_COMMAND = "$FZF_DEFAULT_COMMAND";
    FZF_ALT_C_COMMAND = "fd --type d --hidden --follow --exclude .git";
    
    # Ripgrep settings
    RIPGREP_CONFIG_PATH = "$HOME/.config/ripgrep/config";
  };
}
