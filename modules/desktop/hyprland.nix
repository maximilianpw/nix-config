{ pkgs, lib, ... }:
{
  # Core Hyprland (selectable via existing DM, or start from TTY)
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Essential system services
  services.dbus.enable = true;
  security.polkit.enable = true;

  # Minimal portals (screen sharing / file picker)
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];

  # Keep env vars lean; add only if necessary later
  environment.sessionVariables = {
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Minimal supporting tools
  environment.systemPackages = [
    pkgs.wl-clipboard
    pkgs.kitty
    pkgs.kdePackages.dolphin
    pkgs.wofi
  ];

  # Do not enforce any display manager or seat daemon here; leave to other modules
  services.greetd.enable = true;
  services.greetd.settings.default_session = {
    command = "${pkgs.hyprland}/bin/Hyprland";
    user = "maxpw";
  };  
  services.seatd.enable  = lib.mkForce false;
}