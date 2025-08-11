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

  # Minimal supporting tools
  environment.systemPackages = [
    pkgs.wl-clipboard
    pkgs.kitty
    pkgs.kdePackages.dolphin
    pkgs.wofi
  ];
}