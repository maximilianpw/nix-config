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

  services.seatd.enable = true;             # provide a seat when no “big” DM is used
  services.greetd = {
    enable = true;
    package = pkgs.greetd.tuigreet;
    settings.default_session = {
      command = "tuigreet --time --remember --cmd 'dbus-run-session Hyprland'";
      user = "maxpw";
    };
  };}