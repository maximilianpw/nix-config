# Shell configurations - Nushell (primary), Fish and Bash (compatibility)
{
  config,
  pkgs,
  lib,
  isDarwin,
  ...
}: let
  renderTemplate = path: markers: values: let
    rendered = lib.replaceStrings markers values (builtins.readFile path);
  in
    assert lib.assertMsg
    (lib.all (marker: !lib.hasInfix marker rendered) markers)
    "${toString path} contains an unsubstituted template marker"; rendered;

  agentAliases = {
    c = "codex --yolo";
    ccc = "DISABLE_ZOXIDE=1 claude --dangerously-skip-permissions";
    h = "herdr";
    claudex = "CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1 CLAUDE_CODE_MAX_TOOL_USE_CONCURRENCY=3 ENABLE_TOOL_SEARCH=false claude";
    oc = "opencode";
    p = "pi";
  };

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
    # nh rebuild pilot (plan 007) - side-by-side with `nr`. nh has no
    # platform-neutral switch subcommand and infers the wrong hostname on
    # darwin, so pass the flake attr explicitly there (see plans/007 report).
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
  home.sessionVariables.RIPGREP_CONFIG_PATH = "${config.xdg.configHome}/ripgrep/config";

  programs = {
    bash = {
      enable = true;
      shellAliases = shellAliases // agentAliases;
      initExtra = ''
        if [ -z "$DISABLE_ZOXIDE" ]; then
          eval "$(zoxide init --cmd cd bash)"
        fi
      '';
    };

    nushell = {
      enable = true;
      shellAliases =
        (builtins.removeAttrs shellAliases ["jtp" "ls" "fnix"])
        // (builtins.removeAttrs agentAliases ["ccc" "claudex"]);
      configFile.source = ../config.nu;
      extraConfig = builtins.readFile ../extra-config.nu;
      extraEnv =
        renderTemplate
        ../extra-env.nu
        ["@BASH_INTERACTIVE@"]
        ["${pkgs.bashInteractive}/bin/bash"];
      plugins = with pkgs.nushellPlugins;
      # Plugins pinned to nushell 0.111.0 in nixpkgs-unstable (skim, hcl,
      # semver, desktop_notifications) are ABI-incompatible with nushell
      # 0.112.1 and have been dropped until nixpkgs catches up.
        [
          gstat
          query
        ];
    };

    carapace = {
      enable = true;
      enableFishIntegration = true;
      enableNushellIntegration = true;
    };

    zoxide = {
      enable = true;
      enableBashIntegration = false;
      options = ["--cmd cd"];
    };

    starship = {
      enable = true;
    };

    nix-your-shell = {
      enable = true;
      enableNushellIntegration = true;
      enableFishIntegration = true;
    };

    fish = {
      enable = true;
      shellAliases = shellAliases // agentAliases;
      interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" [
        (builtins.readFile ../config.fish)
        "set -g SHELL ${pkgs.fish}/bin/fish"
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
  };
}
