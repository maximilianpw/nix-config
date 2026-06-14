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
    # nixpkgs 26.05 flipped these defaults to false. Pin to the prior behavior
    # to keep the update purely a version bump; set to false to drop the unused
    # ruby/python3 providers and shrink the wrapper closure.
    withRuby = true;
    withPython3 = true;
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
        bash-language-server
        # CSS/HTML
        vscode-langservers-extracted # cssls, html, jsonls, eslint
        # Docker
        dockerfile-language-server
        # Go
        gopls
        delve # Go debugger
        # golangci-lint comes from packages/dev-tools.nix (also a CLI tool)
        # Note: goimports/gofumpt are installed imperatively by go.nvim's
        # update_all_sync build step (into ~/go/bin); gofmt ships with `go`.
        # Lua
        lua-language-server
        # Nix
        nil # Nix LSP
        # TypeScript/JavaScript
        typescript
        vscode-js-debug
        # Tailwind CSS
        tailwindcss-language-server
        # Rust
        rust-analyzer
        # Zig (the zig compiler itself comes from packages/dev-tools.nix)
        zls
        # TOML
        taplo # TOML LSP
        # YAML
        yaml-language-server
        # === Debug Adapters ===
        # (delve for Go and vscode-js-debug for JS/TS are listed above)
        # === Formatters ===
        # JavaScript/TypeScript/Web
        prettier
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
        alejandra # Nix formatter
        # === Linters ===
        eslint_d # Fast ESLint daemon
        hadolint # Dockerfile linter
        tflint # Terraform linter
        vale # Prose linter
      ];
  };
}
