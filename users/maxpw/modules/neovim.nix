{
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
    withRuby = false;
    withPython3 = false;
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
        # Astro
        astro-language-server
        # Bash/Shell
        bash-language-server
        # CSS/HTML
        vscode-langservers-extracted # cssls, html, jsonls, eslint
        # Docker
        dockerfile-language-server
        # Go
        gopls
        delve # Go debugger
        # Formatters, linters, and Go source tools live in dev-tools.nix so
        # terminal editors and VCS hooks can use the same binaries.
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
        # taplo (TOML LSP + formatter) comes from dev-tools.nix.
        # YAML
        yaml-language-server
        # === Debug Adapters ===
        # (delve for Go and vscode-js-debug for JS/TS are listed above)
        # === Linters ===
        eslint_d # Fast ESLint daemon
        hadolint # Dockerfile linter
        tflint # Terraform linter
        vale # Prose linter
      ];
  };

  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
}
