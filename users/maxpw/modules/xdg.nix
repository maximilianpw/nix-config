# XDG config file management
{
  isDarwin,
  isWSL ? false,
  hostname,
  pkgs,
  lib,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux && !isWSL;

  # Helper function to automatically symlink all files in a directory
  symlinkDir = dir: prefix:
    lib.mapAttrs' (name: type: {
      name = "${prefix}/${name}";
      value = {source = "${dir}/${name}";};
    }) (builtins.readDir dir);

  # Per-host Hyprland overrides
  hasLockScreen = hostname != "main-pc";

  hypridleConf =
    if hasLockScreen
    then ''
      general {
        before_sleep_cmd = hyprctl dispatch dpms on
        after_sleep_cmd = hyprctl dispatch dpms on
      }

      listener {
        timeout = 600         # 10 min
        on-timeout = hyprlock
      }

      listener {
        timeout = 900         # 15 min
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
      }

      listener {
        timeout = 3600        # 1 hour
        on-timeout = systemctl hibernate
      }
    ''
    else ''
    '';

  hostConf =
    if hasLockScreen
    then ''
      bind = $mod, ESCAPE, exec, hyprlock
    ''
    else "";
in {
  xdg.enable = true;

  xdg.configFile =
    {
      "yazi".source = ../yazi;
      "yazi".recursive = true;
    }
    // (
      if isDarwin
      then {
        # Rectangle.app. This has to be imported manually using the app.
        "rectangle/RectangleConfig.json".text = builtins.readFile ../RectangleConfig.json;
      }
      else {}
    )
    // (
      if isLinux
      then
        {
          "ghostty/config".text = builtins.readFile ../ghostty.linux;
          "gammastep/config.ini".text = builtins.readFile ../config.gammastep;
          "rofi".source = ../rofi;
          "rofi".recursive = true;
          "waybar".source = ../waybar;
          "waybar".recursive = true;
          "swaync".source = ../swaync;
          "swaync".recursive = true;
          "wlogout/layout".source = ../wlogout/layout;
          "wlogout/colors.css".source = ../wlogout/colors.css;
          "wlogout/style.css".text =
            builtins.replaceStrings
            ["@WLOGOUT_ICONS@"]
            ["${pkgs.wlogout}/share/wlogout/icons"]
            (builtins.readFile ../wlogout/style.css);
        }
        // (symlinkDir ../hyprland "hypr")
        // {
          "hypr/hypridle.conf".text = hypridleConf;
          "hypr/host.conf".text = hostConf;
        }
      else {}
    );
}
