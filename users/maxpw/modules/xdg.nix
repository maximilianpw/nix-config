# XDG config file management
{
  isDarwin,
  isWSL ? false,
  ...
}: {
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
          "redshift/redshift.conf".text = builtins.readFile ../config.redshift;
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
      else {}
    );
}
