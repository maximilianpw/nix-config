{
  isDarwin,
  isLinuxDesktop,
  inputs,
  pkgs,
  lib,
  ...
}: let
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
    inputs.nix-index-database.homeModules.nix-index
    inputs.stylix.homeModules.stylix
    ./modules/fonts.nix
    ./modules/git.nix
    ./modules/vcs/jujutsu.nix
    ./modules/agent-tools.nix
    ./modules/cmux.nix
    ../../modules/fleet/home-manager.nix
    ./modules/fleet-ssh-key.nix
    ./modules/t3code-server.nix
    ./modules/shells.nix
    ./modules/syncthing.nix
    ./modules/gpg.nix
    ./modules/himalaya.nix
    ./modules/xdg.nix
    ./modules/linux-services.nix
    ./modules/tmux.nix
    ./modules/neovim.nix
    ./modules/packages/dev-tools.nix
    ./modules/packages/terminal-tools.nix
    ./modules/packages/linux-desktop.nix
    ./modules/packages/custom-scripts.nix
  ];

  stylix = lib.mkMerge [
    {
      # home-manager.useGlobalPkgs ignores HM-level nixpkgs.overlays, and
      # stylix's package overlays (on by default, even with stylix disabled)
      # trip HM's nixpkgs deprecation warning on every profile.
      overlays.enable = false;
    }
    (lib.mkIf isLinuxDesktop {
      enable = true;
      autoEnable = false;
      base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/gruvbox-material-dark-hard.yaml";
      targets.ghostty.enable = true;
      targets.waybar.enable = true;
    })
  ];

  home = {
    stateVersion = "25.05";

    sessionPath = [
      "$HOME/.local/bin"
    ];

    sessionVariables =
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
  };

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    nix-index.enable = true;
    nix-index-database.comma.enable = true;

    ssh = {
      enable = true;
      # Keep SSH defaults explicit as Home Manager changes its implicit defaults.
      enableDefaultConfig = false;
      includes = lib.optionals isDarwin ["~/.orbstack/ssh/config"];
      settings."Match host * exec \"test -z $SSH_TTY\"" = {
        IdentityAgent = "%d/.1password/agent.sock";
      };
    };
  };
}
