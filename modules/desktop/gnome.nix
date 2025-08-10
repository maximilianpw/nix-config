{ pkgs, lib, ... }:
{
  # Enable GNOME (Wayland by default via GDM)
  services.xserver = {
    enable = true;
    displayManager.gdm = {
      enable = true;
      wayland = true;
    };
    desktopManager.gnome.enable = true;
  };

  # Graphics acceleration (defensive defaults)
  hardware.opengl.enable = lib.mkDefault true;
  hardware.graphics.enable = lib.mkDefault true;

  # Useful GNOME extensions & tweaks
  environment.systemPackages = with pkgs; [
    gnome-tweaks
    gnomeExtensions.appindicator
    gnomeExtensions.blur-my-shell
    gnomeExtensions.dash-to-dock
    gnomeExtensions.user-themes
  ];

  # XDG portals for GNOME
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome pkgs.xdg-desktop-portal-gtk ];
  };

  # Ensure any previous greetd/seatd settings (Hyprland) are disabled
  services.greetd.enable = lib.mkForce false;
  services.seatd.enable = lib.mkForce false;

  # Force session desktop identifiers to GNOME
  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = lib.mkForce "GNOME";
    XDG_SESSION_TYPE = lib.mkForce "wayland";
  };
}
