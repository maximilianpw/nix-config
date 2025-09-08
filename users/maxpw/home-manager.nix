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
  imports = ["./fonts.nix"];

  isLinux = pkgs.stdenv.isLinux;

  shellAliases = {
    z = "cd";

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

    jd = "jj desc";
    jf = "jj git fetch";
    jn = "jj new";
    jp = "jj git push";
    js = "jj st";

    dcu = "docker compose up";
    dcdn = "docker compose down";
    dcub = "docker compose up --build";
    dcb = "docker compose build";
    dcbc = "docker compose build --no-cache";
  };
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
  home.stateVersion = "25.05";

  xdg.enable = true;

  home.packages = with pkgs;
    [
      # environment
      chezmoi
      _1password-cli
      ngrok
      stow
      alejandra
      nodejs
      python3
      go
      rustc
      rustup
      deno
      lua
      bat
      # terminal dependencies
      checkstyle
      vale
      prettierd
      tree
      fzf
      eslint
      zoxide
      neofetch
      openjdk
      oh-my-posh
      ripgrep
      starship
      fd
      # git
      gnupg
      gh
      lazygit
      gitui
      # ai
      claude-code
      # dev packages
      mongosh
      sops
      btop
      terraform
      cmatrix
      awscli2
      asdf
      oxlint
    ]
    ++ (lib.optionals (isLinux && !isWSL) [
      chromium
      firefox
      rofi-wayland
      ghostty
      # Wayland desktop essentials
      waybar
      mako
      wl-clipboard
      cliphist
      grim
      slurp
      swww
      hyprlock
      hypridle
      polkit_gnome
      thunar
    ]);

  home.sessionVariables =
    {
      EDITOR = "nvim";
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
        "hypr/hyprland.conf".text = builtins.readFile ./hyprland.conf;
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
      push.autoSetupRemote = true;
      pull.rebase = false;
    };
  };

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
      # Source Rust environment only if present
      if [ -f "$HOME/.cargo/env" ]; then
        . "$HOME/.cargo/env"
      fi
    '';
    oh-my-zsh.enable = true;
  };

  programs.fish = {
    enable = true;
    shellAliases = shellAliases;
    interactiveShellInit = lib.strings.concatStrings (lib.strings.intersperse "\n" [
      (builtins.readFile ./config.fish)
      "set -g SHELL ${pkgs.fish}/bin/fish"
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
