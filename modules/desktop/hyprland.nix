{ pkgs, lib, ... }:
{
  # Core compositor
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Portals (prefer hyprland portal)
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland pkgs.xdg-desktop-portal-gtk ];
    # config.common.default = [ "gtk" "hyprland" ]; # uncomment to force order
  };

  # Desktop / Wayland tools
  environment.systemPackages = with pkgs; [
    hyprland
    waybar
    rofi-wayland
    kitty
    grim slurp wl-clipboard
    mako
  ];

  # Session vars for Wayland friendliness
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    MOZ_ENABLE_WAYLAND = "1";
  };

  # Seat management & autologin/session start
  services.seatd.enable = true;
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.hyprland}/bin/Hyprland";
        user = "maxpw"; # adjust if username changes
      };
    };
  };

  security.polkit.enable = true;
}
