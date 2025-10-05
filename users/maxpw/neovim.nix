# NixOS Home Manager configuration for Neovim
# Import this into your home-manager configuration with:
#   imports = [ ./dot_config/nvim/neovim.nix ];
{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Use latest stable Neovim
    package = pkgs.neovim-unwrapped;

    # Environment variables for Neovim
    extraLuaConfig = ''
      -- This runs before your init.lua
      -- Add any NixOS-specific configuration here if needed
    '';

    # Additional packages available to Neovim
    extraPackages = with pkgs; [
      # === Core Tools ===
      # Note: gcc, git, curl, wget, ripgrep, fd already in home.packages
      tree-sitter # Parser generator tool

      # === LSP Servers ===
      # Bash/Shell
      nodePackages.bash-language-server

      # CSS/HTML
      vscode-langservers-extracted # cssls, html, jsonls, eslint

      # Docker
      dockerfile-language-server-nodejs

      # Elixir
      elixir-ls

      # Go
      gopls
      delve # Go debugger
      golangci-lint # Go linter

      # GraphQL
      nodePackages.graphql-language-service-cli

      # JavaScript/TypeScript (handled by typescript-tools.nvim)
      # nodePackages.typescript-language-server  # Not needed with typescript-tools

      # JSON
      # Already in vscode-langservers-extracted

      # Lua
      lua-language-server

      # Nix
      nil # Nix LSP
      nixd # Alternative Nix LSP (you can choose one)
      nixpkgs-fmt # Nix formatter

      # Prisma
      nodePackages.prisma

      # Python
      pyright
      python311Packages.black # Python formatter
      python311Packages.isort # Python import sorter

      # Rust
      rust-analyzer
      rustfmt # Rust formatter

      # Tailwind CSS
      tailwindcss-language-server

      # TOML
      taplo # TOML LSP

      # YAML
      yaml-language-server

      # Nushell (if you use it)
      nushell

      # === Formatters ===
      # JavaScript/TypeScript/Web
      nodePackages.prettier
      prettierd # Faster prettier daemon

      # Lua
      stylua

      # General
      alejandra # Nix formatter (alternative to nixpkgs-fmt)

      # === Linters ===
      nodePackages.eslint_d # Fast ESLint daemon
      hadolint # Dockerfile linter
      nodePackages.jsonlint # JSON linter
      tflint # Terraform linter
      vale # Prose linter
      # golangci-lint already listed above

      # === Debug Adapters ===
      # Go debugger already listed (delve)
      # Node.js debugger (for DAP)
      # Note: vscode-js-debug is complex to package, may need Mason fallback

      # === Additional Tools ===
      # Note: lazygit, nodejs, deno already in home.packages
      nodePackages.typescript # TypeScript compiler
    ];
  };
}
