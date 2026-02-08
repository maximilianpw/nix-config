{
  inputs,
  pkgs,
  lib,
  ...
}: {
  # Core Hyprland with UWSM session management
  programs.hyprland = {
    enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    withUWSM = true;
    xwayland.enable = true;
  };

  # Login manager for Wayland sessions (TTY-friendly)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # Text greeter that launches Hyprland via UWSM
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd start-hyprland";
        user = "greeter";
      };
    };
  };
}
