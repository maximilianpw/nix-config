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
  # For our MANPAGER env var
  # https://github.com/sharkdp/bat/issues/1145
  manpager = pkgs.writeShellScriptBin "manpager" (
    if isDarwin
    then ''
      sh -c 'col -bx | bat -l man -p'
    ''
    else ''
      cat "$1" | col -bx | bat --language man --style plain
    ''
  );
in {
  home.stateVersion = "25.05";

  xdg.enable = true;

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

  home.sessionVariables =
    {
      EDITOR = "nvim";
      PAGER = "less -FirSwX";
      MANPAGER = "${manpager}/bin/manpager";
    }
    // (
      if isDarwin
      then {
        # See: https://github.com/NixOS/nixpkgs/issues/390751
        DISPLAY = "nixpkgs-390751";
      }
      else {}
    );

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
    signing = {
      key = "992CF94F12CF7405147D81FD4AB37B87F45FAC60";
      signByDefault = true;
    };
    extraConfig = {
      branch.autosetuprebase = "always";
      color.ui = true;
      github.user = "MaxPW777";
      init.defaultBranch = "main";
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

  programs.neovim = {
    enable = true;
  };

  services.gpg-agent = {
    enable = isLinux;
    pinentry.package = pkgs.pinentry-tty;

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
