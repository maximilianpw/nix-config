{
  pkgs,
  lib,
  isLinux,
  ...
}: {
  home.packages = lib.optionals isLinux [
    # App launcher
    pkgs.rofi

    # Terminal emulator
    pkgs.ghostty

    # Wayland desktop essentials
    pkgs.waybar
    pkgs.wl-clipboard
    pkgs.cliphist
    pkgs.grim
    pkgs.slurp
    pkgs.hyprlock
    pkgs.hypridle
    pkgs.hyprpaper
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
    pkgs._1password-gui

    # System utilities
    pkgs.pavucontrol
    pkgs.brightnessctl
    pkgs.playerctl
    pkgs.qbittorrent
    pkgs.cava
  ];
}
