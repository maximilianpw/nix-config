{
  pkgs,
  lib,
  isLinux,
  isWSL,
  ...
}: {
  home.packages = lib.optionals (isLinux && !isWSL) [
    # App launcher
    pkgs.rofi

    # Terminal emulator
    pkgs.ghostty

    # Wayland desktop essentials
    pkgs.waybar
    pkgs.mako
    pkgs.wl-clipboard
    pkgs.cliphist
    pkgs.grim
    pkgs.slurp
    pkgs.swww
    pkgs.hyprlock
    pkgs.hypridle
    pkgs.hyprpaper
    pkgs.cava
    pkgs.swaynotificationcenter
    pkgs.redshift
    pkgs.wlogout

    # GUI applications
    pkgs.nautilus
    pkgs.discord
    pkgs.mongodb-compass
    pkgs.protonmail-desktop
    pkgs.jetbrains.webstorm
    pkgs.mullvad-vpn

    # Developer tools
    pkgs.bruno

    # System utilities
    pkgs.pavucontrol
    pkgs.brightnessctl
    pkgs.playerctl
    pkgs.qbittorrent
  ];
}
