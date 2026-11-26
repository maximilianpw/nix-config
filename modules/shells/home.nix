# Shell configurations - Fish (login and interactive), Bash and Zsh (compatibility)
{
  config,
  pkgs,
  lib,
  isDarwin,
  homelab,
  hostRecord,
  ...
}: let
  agentAliases = {
    c = "DISABLE_ZOXIDE=1 claude --dangerously-skip-permissions";
    ccc = "codex --yolo";
    oc = "opencode";
    p = "pi";
  };

  shellAliases = {
    ls = "eza";
    claer = "clear";

    ga = "git add";
    gaa = "git add .";
    gcm = "git commit -m";
    gst = "git status";
    gco = "git checkout";
    gcob = "git checkout -b";
    gd = "git diff";
    gl = "git prettylog";
    gp = "git push";
    gll = "git pull";
    v = "nvim";

    jc = "jj commit";
    jd = "jj diff";
    jf = "jj git fetch";
    jfr = "jj git fetch && jj retrunk";
    jn = "jj new";
    jp = "jj git push";
    js = "jj st";
    jtp = "jj tug && jj git push";

    dcu = "docker compose up";
    dcdn = "docker compose down";
    dcub = "dcompose up --build";
    dcb = "dcompose build";
    dcbc = "dcompose build --no-cache";

    # Nix system management aliases
    nr = "make -C ~/nix-config rebuild";
    nup = "make -C ~/nix-config update";
    # nh trial alongside `nr`. nh has no platform-neutral switch subcommand and
    # infers the wrong hostname on darwin, so pass the flake attr explicitly.
    nhs =
      if isDarwin
      then "nh darwin switch --no-nom -H joyce ~/nix-config"
      else "nh os switch ~/nix-config";

    # Shortcut to setup a nix-shell with fish. This lets you do something like
    # `fnix -p go` to get an environment with Go but use the fish shell along
    # with it.
    fnix = "nix-shell --run fish";
  };
in {
  # Nushell stays available as a tool (`nu`, `nu -c`), not as a configured shell.
  home.packages = [pkgs.nushell];

  home.sessionVariables.RIPGREP_CONFIG_PATH = "${config.xdg.configHome}/ripgrep/config";

  programs = {
    atuin = lib.mkIf hostRecord.atuinSync {
      enable = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
      flags = ["--disable-up-arrow" "--disable-ai"];
      settings = {
        sync_address = homelab.endpoints.atuin.url;
        auto_sync = true;
        sync_frequency = "5m";
        filter_mode = "global";
        secrets_filter = true;
        # Leading-space commands are deliberately omitted from history.
        history_filter = ["^ "];
      };
    };

    bash = {
      enable = true;
      shellAliases = shellAliases // agentAliases;
      initExtra = ''
        if [ -z "$DISABLE_ZOXIDE" ]; then
          eval "$(zoxide init --cmd cd bash)"
        fi
      '';
    };

    # Agent harnesses such as Claude Code run their commands through zsh.
    zsh = {
      enable = true;
      # nixpkgs 26.05 moves the default dotDir to XDG; zsh reads ~/.zshrc.
      dotDir = config.home.homeDirectory;
      shellAliases = shellAliases // agentAliases;
      history = {
        size = 5000;
        save = 5000;
        ignoreAllDups = true;
        ignoreSpace = true;
        share = true;
      };
      completionInit = "autoload -Uz compinit && compinit -C -i";
      initContent = ''
        if [ -z "$DISABLE_ZOXIDE" ]; then
          eval "$(zoxide init --cmd cd zsh)"
        fi
      '';
    };

    carapace = {
      enable = true;
      enableFishIntegration = true;
    };

    zoxide = {
      enable = true;
      enableBashIntegration = false;
      enableZshIntegration = false;
      options = ["--cmd cd"];
    };

    starship = {
      enable = true;
    };

    nix-your-shell = {
      enable = true;
      enableFishIntegration = true;
    };

    fish = {
      enable = true;
      shellAliases = shellAliases // agentAliases;
      interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" [
        (builtins.readFile ./config.fish)
        "set -g SHELL ${pkgs.fish}/bin/fish"
      ]);

      plugins = [
        {
          name = "fish-foreign-env";
          src = pkgs.fetchFromGitHub {
            owner = "oh-my-fish";
            repo = "plugin-foreign-env";
            rev = "b693237c3027b81ac3760d60d159d2be4925ed1c";
            sha256 = "sha256-JyAFxYkPQZs4TfVfBVPKa202SXsAZCyCLzVW+6/PASA=";
          };
        }
      ];
    };
  };
}
