{
  config,
  pkgs,
  ...
}: {
  # Global Home Manager configuration
  # This can be imported by individual user configs

  # The home.packages option allows you to install Nix packages into your environment.
  home.packages = with pkgs; [
    # Core system utilities
    git
    unzip
    curl
    wget

    # Development tools - General
    neovim
    ripgrep
    fd
    fzf
    tree-sitter

    # Development tools - Languages and runtimes
    nodejs_20
    python3
    python311Packages.pip
    rustup
    go
    openjdk

    # Development tools - Language servers and formatters
    lua-language-server
    typescript
    nodePackages.typescript-language-server
    nodePackages.prettier
    nodePackages.eslint_d
    nodePackages."@angular/cli"
    black # Python formatter
    isort # Python import sorter
    stylua # Lua formatter

    # Development tools - Build and Make
    gnumake
    cmake
    gcc

    # Nerd Fonts for terminal
    (nerdfonts.override {fonts = ["FiraCode" "JetBrainsMono" "Hack"];})

    # Additional utilities
    lazygit
  ];

  # Global Home Manager session variables
  home.sessionVariables = {
    EDITOR = "nvim";
    JAVA_HOME = "${pkgs.openjdk}";
    # Add Rust to PATH
    PATH = "$PATH:$HOME/.cargo/bin";
  };

  # Programs configuration
  programs = {
    # Git configuration (global defaults)
    git = {
      enable = true;
      # Add global git aliases and config here
      aliases = {
        st = "status";
        co = "checkout";
        br = "branch";
        ci = "commit";
        df = "diff";
        lg = "log --oneline --graph --all";
      };
    };

    # Zsh configuration
    zsh = {
      enable = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      oh-my-zsh = {
        enable = true;
        theme = "robbyrussell";
        plugins = ["git" "sudo" "docker" "kubectl"];
      };
    };

    # Neovim configuration
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
    };

    # Zoxide for better cd
    zoxide = {
      enable = true;
      enableZshIntegration = true;
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
    };
  };

  # Fonts
  fonts.fontconfig.enable = true;
}
