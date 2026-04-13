# Shell configurations - nushell (primary), fish, bash/zsh (compatibility)
{
  pkgs,
  lib,
  isDarwin,
  ...
}: let
  # Fish shell functions
  fishShellFunctions = ''
    # JJ PR creation with GitHub CLI
    # Usage: jprgh "commit message" [gh pr create args...]
    function jprgh
      jj commit -m $argv[1]
      and jj git push -c '@-'
      and set BRANCH "maximilianpw/push-"(jj log -r '@-' --no-graph -T 'change_id.short()')
      and gh pr create --head $BRANCH $argv[2..-1]
    end

    # JJ PR creation with Graphite CLI
    # Usage: jprgt "commit message" [gt submit args...]
    function jprgt
      jj commit -m $argv[1]
      and jj git push -c '@-'
      and set BRANCH "maximilianpw/push-"(jj log -r '@-' --no-graph -T 'change_id.short()')
      and git checkout $BRANCH
      and gt track
      and gt submit $argv[2..-1]
      and git checkout -
      and jj git import
    end
  '';

  shellAliases = {
    ls = "eza";

    ga = "git add";
    gaa = "git add .";
    gcm = "git commit -m";
    gst = "git status";
    gco = "git checkout";
    gcob = "git checkout -b";
    gd = "git diff";
    gl = "git prettylog";
    gp = "git push";
    v = "nvim";
    c = "DISABLE_ZOXIDE=1 claude --dangerously-skip-permissions";

    jc = "jj commit";
    jd = "jj diff";
    jf = "jj git fetch";
    jn = "jj new";
    jp = "jj git push";
    js = "jj st";
    jtp = "jj tug && jj git push";

    dcu = "docker compose up";
    dcdn = "docker compose down";
    dcub = "docker compose up --build";
    dcb = "docker compose build";
    dcbc = "docker compose build --no-cache";

    chcd = "cd ~/.local/share/chezmoi";
    chap = "chezmoi apply";

    tm = "tmux";
    tma = "tmux attach";
    tml = "tmux list-sessions";
    tmka = "tmux kill-sessions -a";
    tms = "tmuxinator start";

    # Nix system management aliases
    nr = "make -C ~/nix-config rebuild";
    nup = "make -C ~/nix-config update";

    # Shortcut to setup a nix-shell with fish. This lets you do something like
    # `fnix -p go` to get an environment with Go but use the fish shell along
    # with it.
    fnix = "nix-shell --run fish";
  };
in {
  programs.bash = {
    enable = true;
    shellAliases = shellAliases;
    initExtra = ''
      eval "$(mise activate bash)"

      if [ -z "$DISABLE_ZOXIDE" ]; then
        eval "$(zoxide init --cmd cd bash)"
      fi
    '';
  };

  programs.nushell = {
    enable = true;
    shellAliases = builtins.removeAttrs shellAliases ["jtp" "ls" "c" "fnix"];
    configFile.source = ../config.nu;
    extraConfig = ''
      use ($nu.default-config-dir | path join "mise.nu")
      use ($nu.default-config-dir | path join "ghostty.nu")
    '';
    extraEnv = ''
      $env.SHELL = "${pkgs.nushell}/bin/nu"

      let mise_path = $nu.default-config-dir | path join "mise.nu"
      ^mise activate nu | save $mise_path --force

      # Ghostty shell integration - copy to config dir so config.nu can `use` it
      let ghostty_dest = ($nu.default-config-dir | path join "ghostty.nu")
      if ($env | get -o GHOSTTY_RESOURCES_DIR | is-not-empty) {
        let ghostty_src = ($env.GHOSTTY_RESOURCES_DIR | path join "shell-integration" "nushell" "ghostty.nu")
        if ($ghostty_src | path exists) {
          open $ghostty_src | save -f $ghostty_dest
        } else {
          "# ghostty stub" | save -f $ghostty_dest
        }
      } else {
        "# ghostty stub" | save -f $ghostty_dest
      }
    '';
    plugins = with pkgs.nushellPlugins;
      [
        gstat
        query
        skim
        hcl
        semver
      ]
      ++ lib.optionals (!isDarwin) [
        desktop_notifications
      ];
  };

  programs.zsh = {
    enable = true;
    shellAliases = shellAliases;
    history = {
      size = 5000;
      save = 5000;
      ignoreAllDups = true;
      ignoreSpace = true;
      share = true;
    };
    completionInit = "autoload -Uz compinit && compinit -C -i";
    initContent = ''
      eval "$(mise activate zsh)"

      if [ -z "$DISABLE_ZOXIDE" ]; then
        eval "$(zoxide init --cmd cd zsh)"
      fi
    '';
  };

  programs.carapace = {
    enable = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
    options = ["--cmd cd"];
  };

  programs.starship = {
    enable = true;
  };

  programs.fish = {
    enable = true;
    shellAliases = shellAliases;
    interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" [
      (builtins.readFile ../config.fish)
      "set -g SHELL ${pkgs.fish}/bin/fish"
      "mise activate fish | source"
      fishShellFunctions
    ]);

    plugins = [
      {
        name = "fish-fzf";
        src = pkgs.fetchFromGitHub {
          owner = "jethrokuan";
          repo = "fzf";
          rev = "24f4739fc1dffafcc0da3ccfbbd14d9c7d31827a";
          sha256 = "sha256-QyCkksUYELC+TJDZS1C8aL5MBLmDcwM8gMsfkO0p4E8=";
        };
      }
      {
        name = "fish-foreign-env";
        src = pkgs.fetchFromGitHub {
          owner = "oh-my-fish";
          repo = "plugin-foreign-env";
          rev = "dddd9213272a0ab848d474d0cbde12ad034e65bc";
          sha256 = "sha256-er1KI2xSUtTlQd9jZl1AjqeArrfBxrgBLcw5OqinuAM=";
        };
      }
    ];
  };
}
