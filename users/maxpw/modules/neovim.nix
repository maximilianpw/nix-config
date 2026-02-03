{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.neovim = {
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
      dockerfile-language-server

      # Go
      gopls
      delve # Go debugger
      golangci-lint # Go linter

      # Lua
      lua-language-server

      # Nix
      nil # Nix LSP
      nixpkgs-fmt # Nix formatter

      # TypeScript/JavaScript
      nodePackages.typescript

      # Tailwind CSS
      tailwindcss-language-server

      # TOML
      taplo # TOML LSP

      # YAML
      yaml-language-server

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
      tflint # Terraform linter
      vale # Prose linter
      # golangci-lint already listed above

      # === Additional Tools ===
    ];
  };
}
