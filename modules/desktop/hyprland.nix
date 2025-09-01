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
    xwayland.enable = true; # not required to boot, but usually desired
  };

  # Polkit (needed for privilege prompts)
  security.polkit.enable = true;

  # Login manager for Wayland sessions (TTY-friendly)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        # Text greeter that launches Hyprland
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd Hyprland";
        user = "greeter";
      };
    };
  };

  # XDG portals (not required to boot, but fixes app dialogs/screensharing later)
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
}
