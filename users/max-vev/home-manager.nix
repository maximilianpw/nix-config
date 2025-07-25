{
  isWSL,
  isDarwin,
  inputs,
  ...
}: {
  config,
  pkgs,
  lib,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux;

  shellAliases = {
    ga = "git add";
    gcm = "git commit";
    gco = "git checkout";
    gcp = "git cherry-pick";
    gd = "git diff";
    gl = "git prettylog";
    gp = "git push";
    gs = "git status";
    gt = "git tag";

    jd = "jj desc";
    jf = "jj git fetch";
    jn = "jj new";
    jp = "jj git push";
    js = "jj st";
  };
in {
  home.stateVersion = "25.05";

  home.packages = with pkgs;
    [
      chezmoi
      _1password-cli
      ngrok
      checkstyle
      mongosh
      nushell
      rustc
      rustup
      sops
      vale
      go
      gh
      lazygit
      stow
      tree
      deno
      fzf
      eslint
      btop
      terraform
      fish
      cmatrix
      zoxide
      lua
      neofetch
      openjdk
      awscli2
      neovim
      ripgrep
      asdf
      alejandra
      zsh
      go
      nodejs
      python3
      starship
    ]
    ++ (lib.optionals isDarwin [
      cachix
    ])
    ++ (lib.optionals (isLinux && !isWSL) [
      chromium
      firefox
      rofi
      valgrind
    ]);

  programs.gpg.enable = !isDarwin;

  programs.direnv = {
    enable = true;
  };

  programs.git = {
    enable = true;
    userName = "Maximilian PINDER-WHITE";
    userEmail = "mpinderwhite@proton.me";
    aliases = {
      cleanup = "!git branch --merged | grep  -v '\\*\\|master\\|develop' | xargs -n 1 -r git branch -d";
      prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
    };
    extraConfig = {
      branch.autosetuprebase = "always";
      color.ui = true;
    };
  };

  programs.jujutsu = {
    enable = true;
    # I don't use "settings" because the path is wrong on macOS at
    # the time of writing this.
  };

  programs.nushell = {
    enable = true;
    shellAliases = shellAliases;
    extraConfig = ''
      $env.config = {
        show_banner: false
        completions: {
          case_sensitive: false
          quick: true
          partial: true
          algorithm: "fuzzy"
        }
        ls: {
          use_ls_colors: true
          clickable_links: true
        }
        rm: {
          always_trash: false
        }
        table: {
          mode: rounded
          index_mode: always
          show_empty: true
          trim: {
            methodology: wrapping
            wrapping_try_keep_words: true
          }
        }
        explore: {
          help_banner: true
          exit_esc: true
          command_bar_text: '#C4C9C6'
          status_bar_background: {fg: '#1D1F21' bg: '#C4C9C6'}
          highlight: {bg: 'yellow' fg: 'black'}
          status: {
            error: {fg: 'white' bg: 'red'}
            warn: {}
            info: {}
          }
          selected_cell: {fg: 'white' bg: '#777777'}
        }
        history: {
          max_size: 100_000
          sync_on_enter: true
          file_format: "plaintext"
        }
        filesize: {
          metric: false
          format: "auto"
        }
        cursor_shape: {
          emacs: line
          vi_insert: block
          vi_normal: underscore
        }
        edit_mode: emacs
        shell_integration: true
        buffer_editor: "nvim"
        use_ansi_coloring: true
        bracketed_paste: true
        render_right_prompt_on_last_line: false
      }

      # Custom functions
      def ll [] { ls -la }
      def la [] { ls -a }
      def .. [] { cd .. }
      def ... [] { cd ../.. }
      def .... [] { cd ../../.. }

      # Git helpers that work with your aliases
      def gst [] { git status }
      def glog [] { git prettylog }
    '';
    extraEnv = ''
      $env.EDITOR = "nvim"
      $env.BROWSER = "open"
      $env.PAGER = "less"
    '';
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
