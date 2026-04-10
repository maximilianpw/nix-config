{
  isDarwin,
  isWSL ? false,
  inputs,
  hostname,
  config,
  pkgs,
  lib,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
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
    ./modules/gpg.nix
    ./modules/xdg.nix
    ./modules/linux-services.nix
    ./modules/tmux.nix
    ./modules/neovim.nix
    ./modules/packages/dev-tools.nix
    ./modules/packages/terminal-tools.nix
    ./modules/packages/linux-desktop.nix
  ];

  home.stateVersion = "25.05";

  home.sessionVariables =
    {
      EDITOR = "nvim";
      VISUAL = "nvim";
      SHELL = lib.getExe settings.defaultShell;
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

  programs.ssh = {
    enable = true;
    # Keep SSH defaults explicit as Home Manager changes its implicit defaults.
    enableDefaultConfig = false;
    includes = lib.optionals isDarwin ["~/.orbstack/ssh/config"];
    matchBlocks."*" = {
      extraOptions.IdentityAgent = "%d/.1password/agent.sock";
    };
  };
}
