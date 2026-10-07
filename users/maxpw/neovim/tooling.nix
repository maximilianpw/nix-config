# Editor-only tools Neovim invokes directly (language servers, debuggers,
# linters). Shared by the Home Manager editor and the Nixvim packages so both
# resolve the same binaries. Formatters and Go source tools live in
# modules/packages/dev-tools.nix so terminals and VCS hooks can use them too.
pkgs:
with pkgs;
  lib.optionals stdenv.hostPlatform.isLinux [
    # C compiler is required by nvim-treesitter parser builds (`tree-sitter build` invokes `cc`).
    # Keep this Linux-only; on macOS, prefer Apple's toolchain.
    stdenv.cc
  ]
  ++ [
    tree-sitter # Parser generator tool
    astro-language-server
    bash-language-server
    vscode-langservers-extracted # cssls, html, jsonls, eslint
    dockerfile-language-server
    gopls
    delve # Go debugger
    lua-language-server
    nil # Nix LSP
    typescript
    vscode-js-debug
    tailwindcss-language-server
    rust-analyzer
    # Zig (the zig compiler itself comes from packages/dev-tools.nix)
    zls
    # taplo (TOML LSP + formatter) comes from dev-tools.nix.
    yaml-language-server
    eslint_d # Fast ESLint daemon
    hadolint # Dockerfile linter
    tflint # Terraform linter
    vale # Prose linter
  ]
