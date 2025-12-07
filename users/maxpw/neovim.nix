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

      # Elixir
      elixir-ls

      # Go
      gopls
      delve # Go debugger
      golangci-lint # Go linter

      # JavaScript/TypeScript (handled by typescript-tools.nvim)
      # nodePackages.typescript-language-server  # Not needed with typescript-tools

      # JSON
      # Already in vscode-langservers-extracted

      # Lua
      lua-language-server

      # Nix
      nil # Nix LSP
      nixpkgs-fmt # Nix formatter

      # Prisma
      nodePackages.prisma

      # Python
      pyright
      python311Packages.black # Python formatter
      python311Packages.isort # Python import sorter

      # Rust
      pkgs.rust-bin.nightly.latest.default
      rust-analyzer
      rustfmt

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
