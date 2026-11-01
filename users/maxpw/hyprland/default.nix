{
  config,
  isLinuxDesktop,
  currentSystemUserDir,
  hostname,
  lib,
  pkgs,
  ...
}: let
  homeFiles = import ../../../lib/home-files.nix {
    inherit lib;
    mkOutOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;
  };

  hyprConfigPath = "${config.home.homeDirectory}/nix-config/users/${currentSystemUserDir}/hyprland/hypr";
  uwsmEnv = ''
    export GDK_SCALE=1.6
    export GDK_DPI_SCALE=1
    export GDK_BACKEND=wayland,x11
    export QT_QPA_PLATFORM='wayland;xcb'
    export MOZ_ENABLE_WAYLAND=1
    export XCURSOR_THEME=Vanilla-DMZ
    export XCURSOR_SIZE=128
  '';

  hasLockScreen = hostname != "kim";

  hostLua =
    if hasLockScreen
    then ''
      hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("hyprlock"))
    ''
    else "";

  hypridleConfig =
    if hasLockScreen
    then ''
      listener {
        timeout = 600
        on-timeout = hyprlock
      }

      listener {
        timeout = 900
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
      }

      listener {
        timeout = 3600
        on-timeout = systemctl hibernate
      }
    ''
    else ''
      listener {
        timeout = 900
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
      }
    '';
in
  lib.mkIf isLinuxDesktop {
    home.packages =
      [
        pkgs.waybar
        pkgs.grim
        pkgs.slurp
        pkgs.hyprpaper
        pkgs.hypridle
        pkgs.swaynotificationcenter
        pkgs.gammastep
        pkgs.wlogout
        pkgs.networkmanagerapplet

        # Focus existing window or launch app (used by hyper key bindings)
        (pkgs.writeShellScriptBin "focus-or-launch" ''
          export FOCUS_OR_LAUNCH_AWK=${lib.escapeShellArg "${pkgs.gawk}/bin/awk"}
          ${builtins.readFile ../../../scripts/user/focus-or-launch.sh}
        '')
      ]
      ++ lib.optionals hasLockScreen [
        pkgs.hyprlock
      ];

    xdg.configFile =
      {
        "gammastep/config.ini".text = builtins.readFile ./gammastep.ini;
        "uwsm/env".text = uwsmEnv;
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
      // (homeFiles.symlinkDir {
        dir = ./hypr;
        outOfStoreDir = hyprConfigPath;
        prefix = "hypr";
        exclude = ["hyprland.conf"];
      })
      // {
        "hypr/host.lua".text = hostLua;
        "hypr/hypridle.conf".text = hypridleConfig;
      };
  }
