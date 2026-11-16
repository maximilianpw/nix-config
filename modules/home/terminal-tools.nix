{
  inputs,
  isDarwin,
  lib,
  pkgs,
  ...
}: let
  # https://github.com/sharkdp/bat/issues/1145
  manpager = pkgs.writeShellScriptBin "manpager" ''
    col -bx | ${pkgs.bat}/bin/bat -l man -p --paging=always
  '';
in {
  imports = [inputs.nix-index-database.homeModules.nix-index];

  programs = {
    nix-index.enable = true;
    nix-index-database.comma.enable = true;
  };

  home.sessionVariables = {
    PAGER = "less -FirSwX";
    MANPAGER = "${manpager}/bin/manpager";
    MANROFFOPT = "-c";
  };

  home.packages =
    [
      # Local log viewer (own project, built from its flake)
      inputs.loggle.packages.${pkgs.stdenv.hostPlatform.system}.default
      # Linear issues with a Rex session per issue (own project)
      inputs.linrex.packages.${pkgs.stdenv.hostPlatform.system}.default
      # File navigation & search
      pkgs.bat
      pkgs.eza
      pkgs.tree
      pkgs.fzf
      pkgs.ripgrep
      pkgs.fd
      pkgs.yazi
      pkgs.jq
      pkgs.uv

      # Network & remote access
      pkgs.autossh
      pkgs.mosh
      pkgs.rsync
      pkgs.sshfs
      pkgs.wakeonlan

      # GnuPG is supplied by Homebrew on Darwin alongside pinentry-mac.
    ]
    ++ lib.optional (!isDarwin) pkgs.gnupg
    ++ [
      pkgs.lazydocker

      # System utilities
      pkgs.fastfetch
      pkgs.btop
      pkgs.nh
      pkgs.cmatrix

      # Compression & file tools
      pkgs.zip
      pkgs.unzip

      # Linting & validation
      pkgs.glow
      pkgs.python313Packages.mkdocs
      pkgs.python313Packages.mkdocs-material
      pkgs.python313Packages.mkdocs-mermaid2-plugin
      pkgs.python313Packages.pymdown-extensions

      # Security & secrets
      pkgs.bitwarden-cli
      pkgs.ngrok
    ]
    # Darwin uses 1Password's signed Homebrew CLI for desktop-app integration.
    ++ lib.optionals (!isDarwin) [pkgs._1password-cli pkgs.xdg-utils];
}
