{
  isLinuxDesktop,
  hostname,
  pkgs,
  lib,
  ...
}: {
  home.packages =
    lib.optionals isLinuxDesktop [
      # App launcher
      pkgs.rofi

      # Terminal emulators
      pkgs.ghostty
      pkgs.kitty

      # Wayland desktop essentials
      pkgs.waybar
      pkgs.wl-clipboard
      pkgs.cliphist
      pkgs.grim
      pkgs.slurp
      pkgs.hyprpaper
      pkgs.hypridle
      pkgs.libnotify
      pkgs.swaynotificationcenter
      pkgs.gammastep
      pkgs.wlogout
      pkgs.networkmanagerapplet

      # GUI applications
      pkgs.nautilus
      pkgs.discord
      pkgs.mongodb-compass
      pkgs.protonmail-desktop
      pkgs.mullvad-vpn
      pkgs.obsidian

      # System utilities
      pkgs.pavucontrol
      pkgs.brightnessctl
      pkgs.playerctl
      pkgs.cava

      # Focus existing window or launch app (used by hyper key bindings)
      (pkgs.writeShellScriptBin "focus-or-launch" ''
        export FOCUS_OR_LAUNCH_AWK=${lib.escapeShellArg "${pkgs.gawk}/bin/awk"}
        ${builtins.readFile ../../../../scripts/focus-or-launch.sh}
      '')
    ]
    ++ lib.optionals (isLinuxDesktop && hostname != "kim") [
      pkgs.hyprlock
    ];
}
