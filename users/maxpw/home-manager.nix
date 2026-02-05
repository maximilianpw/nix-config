{
  isDarwin,
  isWSL ? false,
  inputs,
  ...
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux && !isWSL;

  # For our MANPAGER env var
  # https://github.com/sharkdp/bat/issues/1145
  manpager = pkgs.writeShellScriptBin "manpager" ''
    # Read from stdin, clean overstrikes, then send to bat
    # -l man : syntax highlighting for manpages
    # -p     : plain; no extra decorations
    # --paging=always : ensure paging when run in a terminal
    col -bx | ${pkgs.bat}/bin/bat -l man -p --paging=always
  '';
in {
  imports = [
    ./modules/fonts.nix
    ./modules/git.nix
    ./modules/shells.nix
    (import ./modules/gpg.nix {inherit isDarwin isWSL;})
    (import ./modules/xdg.nix {inherit isDarwin isWSL;})
    (import ./modules/linux-services.nix {inherit isWSL;})
    ./modules/tmux.nix
    ./modules/packages/dev-tools.nix
    ./modules/packages/terminal-tools.nix
    (import ./modules/packages/linux-desktop.nix {
      inherit pkgs lib isLinux;
    })
  ];

  home.stateVersion = "25.05";

  home.sessionVariables =
    {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less -FirSwX";
      MANPAGER = "${manpager}/bin/manpager";
      MANROFFOPT = "-c";
    }
    // (
      if isDarwin
      then {
        # See: https://github.com/NixOS/nixpkgs/issues/390751
        DISPLAY = "nixpkgs-390751";
      }
      else {}
    );

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.neovim = lib.mkMerge [
    {
      enable = true;
      package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      extraPackages = (import ./modules/neovim.nix {inherit config pkgs lib;}).programs.neovim.extraPackages;
    }
  ];
}
