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
    gaa = "git add .";
    gcm = "git commit";
    gst = "git status";
    gco = "git checkout";
    gcp = "git cherry-pick";
    gd = "git diff";
    gl = "git prettylog";
    gp = "git push";
    v = "nvim";

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
      gnupg
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
      go
      oh-my-posh
      nodejs
      python3
      starship
    ]
    ++ (lib.optionals (isLinux && !isWSL) [
      chromium
      firefox
      rofi
    ]);

  xdg.configFile =
    {
      #"i3/config".text = builtins.readFile ./i3;
      #"rofi/config.rasi".text = builtins.readFile ./rofi;
    }
    // (
      if isDarwin
      then {
        # Rectangle.app. This has to be imported manually using the app.
        "rectangle/RectangleConfig.json".text = builtins.readFile ./RectangleConfig.json;
      }
      else {}
    )
    // (
      if isLinux
      then {
        "ghostty/config".text = builtins.readFile ./ghostty.linux;
      }
      else {}
    );
  programs.gpg.enable = !isDarwin;

  programs.jujutsu = {
    enable = true;
    # I don't use "settings" because the path is wrong on macOS at
    # the time of writing this.
  };

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

  programs.bash = {
    enable = true;
    shellAliases = shellAliases;
    shellOptions = [];
    historyControl = ["ignoredups" "ignorespace"];
    profileExtra = ''
      . "$HOME/.cargo/env"
    '';
  };

  programs.nushell = {
    enable = true;
    shellAliases = shellAliases;
    configFile.source = ./config.nu;
  };

  programs.zsh = {
    enable = true;
    shellAliases = shellAliases;
    initContent = builtins.readFile ./zshrc;
    envExtra = ''
      . "$HOME/.cargo/env"
    '';
    oh-my-zsh.enable = true;
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
