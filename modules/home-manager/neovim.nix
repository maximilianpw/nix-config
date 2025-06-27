{
  config,
  pkgs,
  ...
}: {
  # Neovim configuration module
  # This module provides a comprehensive Neovim setup with plugins and LSP support
  
  home.packages = with pkgs; [
    # Neovim and core editing tools
    neovim
    tree-sitter

    # Language servers for Neovim
    lua-language-server
    typescript
    nodePackages.typescript-language-server
    
    # Formatters for various languages
    nodePackages.prettier
    nodePackages.eslint_d
    black # Python formatter
    isort # Python import sorter
    stylua # Lua formatter
  ];

  # Programs configuration
  programs = {
    # Neovim configuration
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      
      # Basic Neovim configuration
      extraConfig = ''
        " Basic settings
        set number
        set relativenumber
        set tabstop=2
        set shiftwidth=2
        set expandtab
        set smartindent
        set wrap
        set smartcase
        set noswapfile
        set nobackup
        set undodir=~/.config/nvim/undodir
        set undofile
        set incsearch
        set scrolloff=8
        set signcolumn=yes
        set updatetime=50
        set colorcolumn=80
      '';
      
      # Plugins can be added here
      plugins = with pkgs.vimPlugins; [
        # Essential plugins
        plenary-nvim
        telescope-nvim
        
        # LSP and completion
        nvim-lspconfig
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path
        
        # Syntax highlighting
        nvim-treesitter
        
        # Git integration
        gitsigns-nvim
        
        # File explorer
        nvim-tree-lua
        
        # Status line
        lualine-nvim
        
        # Color scheme
        gruvbox-nvim
      ];
    };
  };

  # Session variables for Neovim
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
