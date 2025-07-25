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
      claude-code
      _1password-cli
      ngrok
      checkstyle
      mongosh
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
      nushell
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

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
