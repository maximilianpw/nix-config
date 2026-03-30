{
  pkgs,
  lib,
  isLinux,
  hostname,
  ...
}: {
  home.packages =
    lib.optionals isLinux [
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
      pkgs.t3code

      # System utilities
      pkgs.pavucontrol
      pkgs.brightnessctl
      pkgs.playerctl
      pkgs.qbittorrent
      pkgs.cava

      # Focus existing window or launch app (used by hyper key bindings)
      (pkgs.writeShellScriptBin "focus-or-launch" ''
        class="$1"
        shift
        if hyprctl clients | grep -q "class: $class"; then
          hyprctl dispatch focuswindow "class:$class"
        else
          exec "$@"
        fi
      '')
    ]
    ++ lib.optionals (isLinux && hostname != "main-pc") [
      pkgs.hyprlock
    ];
}
