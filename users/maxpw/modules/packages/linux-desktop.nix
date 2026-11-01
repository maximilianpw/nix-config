{
  isLinuxDesktop,
  pkgs,
  lib,
  ...
}: {
  home.packages = lib.optionals isLinuxDesktop [
    # Terminal emulators
    pkgs.ghostty
    pkgs.kitty

    # Wayland desktop essentials
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.zenity

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
  ];
}
