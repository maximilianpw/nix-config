{
  inputs,
  pkgs,
  lib,
  ...
}: {
  # Core Hyprland (selectable via existing DM, or start from TTY)
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # Minimal supporting tools
  environment.systemPackages = [
    pkgs.kitty
  ];
}

