# Shell configurations - bash, zsh, fish, nushell
{inputs, ...}: {
  pkgs,
  lib,
  ...
}: let
  shellAliases = {
    z = "cd";
    ls = "eza";

    ga = "git add";
    gaa = "git add .";
    gcm = "git commit -m";
    gst = "git status";
    gco = "git checkout";
    gcob = "git checkout -b";
    gcp = "git cherry-pick";
    gd = "git diff";
    gl = "git prettylog";
    gp = "git push";
    v = "nvim";
    c = "claude --dangerously-skip-permissions";

    jd = "jj desc";
    jc = "jj commit";
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

    chcd = "chezmoi cd";
    chap = "chezmoi apply";

    # Nix system management aliases
    nr = "make -C ~/nix-config rebuild";
    nup = "make -C ~/nix-config update";
    nch = "make -C ~/nix-config check";
    ngc = "make -C ~/nix-config gc";
    ngen = "make -C ~/nix-config generations";
    ninfo = "make -C ~/nix-config info";

    # Shortcut to setup a nix-shell with fish. This lets you do something like
    # `fnix -p go` to get an environment with Go but use the fish shell along
    # with it.
    fnix = "nix-shell --run fish";
  };
in {
  programs.bash = {
    enable = true;
    shellAliases = shellAliases;
    shellOptions = [];
    historyControl = ["ignoredups" "ignorespace"];
    profileExtra = ''
      # Source Rust environment only if it exists (fresh installs won't have rustup yet)
      if [ -f "$HOME/.cargo/env" ]; then
        . "$HOME/.cargo/env"
      fi

      # JJ PR creation with GitHub CLI
      jprgh() {
        jj commit && \
        jj git push -c '@-' && \
        jj edit '@-' && \
        BRANCH='maximilianpw/push-'"$(jj log -r '@' --no-graph -T 'change_id.short()')" && \
        gh pr create --head "$BRANCH" "$@"
      }

      # JJ PR creation with Graphite CLI
      jprgt() {
        jj commit && \
        jj git push -c '@-' && \
        jj edit '@-' && \
        BRANCH='maximilianpw/push-'"$(jj log -r '@' --no-graph -T 'change_id.short()')" && \
        gt pr create --head "$BRANCH" "$@"
      }
    '';
  };

  programs.nushell = {
    enable = true;
    shellAliases = shellAliases;
    configFile.source = ../config.nu;
  };

  programs.zsh = {
    enable = true;
    shellAliases = shellAliases;
    initContent = builtins.readFile ../zshrc;
    envExtra = ''
      # Source Rust environment only if present
      if [ -f "$HOME/.cargo/env" ]; then
        . "$HOME/.cargo/env"
      fi

      # JJ PR creation with GitHub CLI
      jprgh() {
        jj commit && \
        jj git push -c '@-' && \
        jj edit '@-' && \
        BRANCH='maximilianpw/push-'"$(jj log -r '@' --no-graph -T 'change_id.short()')" && \
        gh pr create --head "$BRANCH" "$@"
      }

      # JJ PR creation with Graphite CLI
      jprgt() {
        jj commit && \
        jj git push -c '@-' && \
        jj edit '@-' && \
        BRANCH='maximilianpw/push-'"$(jj log -r '@' --no-graph -T 'change_id.short()')" && \
        gt pr create --head "$BRANCH" "$@"
      }
    '';
    oh-my-zsh.enable = true;
  };

  programs.fish = {
    enable = true;
    shellAliases = shellAliases;
    interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" [
      (builtins.readFile ../config.fish)
      "set -g SHELL ${pkgs.fish}/bin/fish"
      ''
        # JJ PR creation with GitHub CLI
        function jprgh
          jj commit
          and jj git push -c '@-'
          and jj edit '@-'
          and set BRANCH "maximilianpw/push-"(jj log -r '@' --no-graph -T change_id.short())
          and gh pr create --head ''$BRANCH ''$argv
        end

        # JJ PR creation with Graphite CLI
        function jprgt
          jj commit
          and jj git push -c '@-'
          and jj edit '@-'
          and set BRANCH "maximilianpw/push-"(jj log -r '@' --no-graph -T change_id.short())
          and gt pr create --head ''$BRANCH ''$argv
        end
      ''
    ]);

    plugins =
      map (n: {
        name = n;
        src = inputs.${n};
      }) [
        "fish-fzf"
        "fish-foreign-env"
      ];
  };
}
