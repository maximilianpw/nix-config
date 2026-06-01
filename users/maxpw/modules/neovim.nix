{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.neovim = {
    enable = true;
    package = pkgs.unstable.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    extraPackages = with pkgs;
      lib.optionals stdenv.hostPlatform.isLinux [
        # C compiler is required by nvim-treesitter parser builds (`tree-sitter build` invokes `cc`).
        # Keep this Linux-only; on macOS, prefer Apple's toolchain.
        stdenv.cc
      ]
      ++ [
        # === Core Tools ===
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
        # Note: goimports/gofumpt are installed imperatively by go.nvim's
        # update_all_sync build step (into ~/go/bin); gofmt ships with `go`.
        # Lua
        lua-language-server
        # Nix
        nil # Nix LSP
        nixpkgs-fmt # Nix formatter
        # TypeScript/JavaScript
        nodePackages.typescript
        vscode-js-debug
        # Tailwind CSS
        tailwindcss-language-server
        # Rust
        rust-analyzer
        # Zig
        zls # Zig LSP
        # TOML
        taplo # TOML LSP
        # YAML
        yaml-language-server
        # === Debug Adapters ===
        # (delve for Go and vscode-js-debug for JS/TS are listed above)
        netcoredbg # C# / .NET debug adapter (config/dap/languages.lua)
        # === Formatters ===
        # JavaScript/TypeScript/Web
        nodePackages.prettier
        prettierd # Faster prettier daemon
        # Lua
        stylua
        # Python (conform: ruff_format then black)
        ruff
        black
        # C/C++ (conform: clang_format)
        clang-tools
        # Shell (sh/bash/zsh)
        shfmt
        # General
        alejandra # Nix formatter (alternative to nixpkgs-fmt)
        # === Linters ===
        nodePackages.eslint_d # Fast ESLint daemon
        hadolint # Dockerfile linter
        tflint # Terraform linter
        vale # Prose linter
      ];
  };
}