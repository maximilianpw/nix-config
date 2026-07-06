{
  config,
  isDarwin,
  isLinuxDesktop,
  isWSL,
  inputs,
  pkgs,
  lib,
  ...
}: let
  settings = import ./settings.nix {inherit pkgs;};
  useSopsGithubSshKey = !isDarwin && !isLinuxDesktop && !isWSL;
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

    activation.ensureOnePasswordAgentSymlink = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
      if [ ${lib.escapeShellArg (
        if isDarwin
        then "1"
        else "0"
      )} = 1 ]; then
        agent_dir="${config.home.homeDirectory}/.1password"
        agent_target="${config.home.homeDirectory}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

        mkdir -p "$agent_dir"
        ln -sfn "$agent_target" "$agent_dir/agent.sock"
      fi
    '';

    file = lib.mkIf isDarwin {
      ".ssh/github-authentication_ed25519.pub".text = settings.sshKeys.githubAuthentication + "\n";
      ".ssh/main-pc_1password_ed25519.pub".text = settings.sshKeys.mainPcUser + "\n";
    };

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
          SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";
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
      settings = lib.mkMerge [
        (lib.mkIf isDarwin {
          "github.com" = {
            HostName = "github.com";
            User = "git";
            IdentityAgent = "%d/.1password/agent.sock";
            IdentityFile = "~/.ssh/github-authentication_ed25519.pub";
            IdentitiesOnly = "yes";
            AddKeysToAgent = "no";
          };
        })
        (lib.mkIf useSopsGithubSshKey {
          "github.com" = {
            HostName = "github.com";
            User = "git";
            IdentityFile = "/run/secrets/github-ssh-private-key";
            IdentitiesOnly = "yes";
            AddKeysToAgent = "no";
          };
        })
      ];
    };
  };
}
