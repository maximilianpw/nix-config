{ pkgs, lib, ... }:
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  # Wayland portals
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-wlr pkgs.xdg-desktop-portal-gtk ];
  };

  environment.systemPackages = with pkgs; [
    hyprland
    waybar
    rofi-wayland
    kitty
    grim slurp wl-clipboard
    mako
  ];

  # Enable seatd (if no full display manager)
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "Hyprland";
        user = "maxpw";
      };
    };
  };

  # Input / pipewire (already enabled elsewhere but kept for clarity)
  security.polkit.enable = true;
}
