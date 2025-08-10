{ pkgs, lib, ... }:
{
  # Minimal Hyprland compositor (no autologin, can be selected from GDM)
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Basic portals for screen sharing / flatpak integration
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
  };

  # Minimal supporting tools; keep small to avoid bloat
  environment.systemPackages = with pkgs; [
    hyprland
    kitty
    wl-clipboard
  ];

  # Wayland-friendly environment vars (kept minimal)
  environment.sessionVariables = {
    XDG_SESSION_TYPE = lib.mkDefault "wayland";
    XDG_CURRENT_DESKTOP = lib.mkDefault "Hyprland";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Explicitly ensure we don't force seatd or greetd (GDM will handle session selection)
  services.greetd.enable = lib.mkForce false;
  services.seatd.enable = lib.mkForce false;

  security.polkit.enable = true;
}
