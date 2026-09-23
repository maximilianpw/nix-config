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
        tree-sitter # Parser generator tool
        astro-language-server
        bash-language-server
        vscode-langservers-extracted # cssls, html, jsonls, eslint
        dockerfile-language-server
        gopls
        delve # Go debugger
        # Formatters, linters, and Go source tools live in dev-tools.nix so
        # terminal editors and VCS hooks can use the same binaries.
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
      ];
  };

  xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
}
