{
  config,
  pkgs,
  ...
}: {
  # Neovim configuration module
  # This module only provides packages needed for your nvim configuration
  # All configuration is handled by your dotfiles via the .config symlink
  
  home.packages = with pkgs; [
    # Language servers (from your LSP config in nvim/lua/plugins/lsp/init.lua)
    clang-tools      # clangd
    gopls           # Go LSP
    pyright         # Python LSP  
    nodePackages.typescript-language-server  # ts_ls (TypeScript)
    dockerfile-language-server-nodejs        # dockerls
    tailwindcss-language-server              # tailwindcss
    lua-language-server                      # lua_ls
    
    # Formatters and linters (from mason-tool-installer config)
    stylua          # Lua formatter
    prettierd       # JavaScript/TypeScript formatter (faster prettier)
    eslint_d        # Faster ESLint
    
    # Additional development tools
    tree-sitter     # Syntax highlighting
    ripgrep         # Required by telescope and other plugins
    fd              # Required by telescope
    git             # Required by git plugins
    nodejs_20       # Required for many LSPs and tools
    
    # Debug adapters (for nvim-dap if you use debugging)
    # lldb moved to system packages in common.nix
    delve           # For Go debugging
    
    # Additional tools that might be needed
    unzip           # For plugin installations
    # gcc, gnumake moved to system packages in common.nix
    
    # Java tooling (from your java plugins folder)
    openjdk         # Java runtime
    maven           # Java build tool
    gradle          # Alternative Java build tool
  ];

  # Minimal neovim setup - let dotfiles handle configuration
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    
    # Extra packages needed at runtime
    extraPackages = with pkgs; [
      # Language runtimes (avoid duplicating what's in development.nix)
      python3
      nodejs_20
      # rustc, cargo provided by rustup in development.nix
      go
      openjdk
      
      # Build tools (moved to system packages in common.nix)
      # gcc, gnumake, cmake now system packages
      
      # Utils
      curl
      wget
      git
      unzip
      
      # Tree-sitter CLI for custom parsers
      tree-sitter
    ];
    
    # No configuration here - dotfiles handle everything via .config symlink
  };
  
  # Session variables moved to dotfiles (handled by .zshrc symlink)
  # EDITOR and VISUAL should be set in your dotfiles
}
