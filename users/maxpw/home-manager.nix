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

  # Helper function to automatically symlink all files in a directory
  symlinkDir = dir: prefix:
    lib.mapAttrs' (name: type: {
      name = "${prefix}/${name}";
      value = {source = "${dir}/${name}";};
    }) (builtins.readDir dir);

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

    jd = "jj desc";
    jc = "jj commit";
    jf = "jj git fetch";
    jn = "jj new";
    jp = "jj git push";
    js = "jj st";

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
    ./fonts.nix
    ./packages/dev-tools.nix
    ./packages/terminal-tools.nix
    (import ./packages/linux-desktop.nix {
      inherit pkgs lib isLinux isWSL;
    })
  ];

  home.stateVersion = "25.05";

  xdg.enable = true;

  home.sessionVariables =
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
      }
      else {}
    );

  xdg.configFile =
    {
      "ranger".source = ./ranger;
      "ranger".recursive = true;
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
      then
        {
          "ghostty/config".text = builtins.readFile ./ghostty.linux;
          "redshift/redshift.conf".text = builtins.readFile ./config.redshift;
          # Hyprland main configs
          # "hypr/hyprland.conf".source = ./hyprland/hyprland.conf;
          # "hypr/hyprpaper.conf".source = ./hyprland/hyprpaper.conf;
          # "hypr/hypridle.conf".source = ./hyprland/hypridle.conf;
          # "hypr/hyprlock.conf".source = ./hyprland/hyprlock.conf;
          # Other configs
          "rofi".source = ./rofi;
          "rofi".recursive = true;
          "waybar".source = ./waybar;
          "waybar".recursive = true;
          "swaync".source = ./swaync;
          "swaync".recursive = true;
          "wlogout/layout".source = ./wlogout/layout;
          "wlogout/colors.css".source = ./wlogout/colors.css;
          "wlogout/style.css".text =
            builtins.replaceStrings
            ["@WLOGOUT_ICONS@"]
            ["${pkgs.wlogout}/share/wlogout/icons"]
            (builtins.readFile ./wlogout/style.css);
        }
        // (symlinkDir ./hyprland "hypr")
      else {}
    );

  programs.gpg.enable = !isDarwin;

  programs.jujutsu = {
    enable = true;
    # I don't use "settings" because the path is wrong on macOS at
    # the time of writing this.
  };

  programs.git = {
    enable = true;
    signing = {
      key = "992CF94F12CF7405147D81FD4AB37B87F45FAC60";
      signByDefault = true;
    };
    lfs.enable = true;
    settings = {
      user = {
        name = "Maximilian PINDER-WHITE";
        email = "mpinderwhite@proton.me";
      };
      alias = {
        cleanup = "!git branch --merged | grep -E -v '\\*|master|develop' | xargs -n 1 -r git branch -d";
        prettylog = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(r) %C(bold blue)<%an>%Creset' --abbrev-commit --date=relative";
      };
      branch.autosetuprebase = "always";
      color.ui = true;
      github.user = "maximilianpw";
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

  services.gpg-agent = {
    enable = isLinux;
    pinentry.package = pkgs.pinentry-gnome3;

    # cache the keys forever so we don't get asked for a password
    defaultCacheTtl = 31536000;
    maxCacheTtl = 31536000;
  };

  systemd.user.services.polkit-gnome = lib.mkIf (isLinux && !isWSL) {
    Unit = {
      Description = "polkit-gnome Authentication Agent";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
    Install = {WantedBy = ["graphical-session.target"];};
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf (isLinux && !isWSL) {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };

  programs.neovim = lib.mkMerge [
    {
      enable = true;
      package = inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
    }
    (lib.mkIf (isLinux && !isWSL) {
      extraPackages = (import ./neovim.nix {inherit config pkgs lib;}).programs.neovim.extraPackages;
    })
  ];
}
