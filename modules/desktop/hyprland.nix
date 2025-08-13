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

  # Minimal supporting tools
  environment.systemPackages = [
    pkgs.kitty
  ];

  # If lspci shows VMware SVGA (vmwgfx), use this instead:
  boot.initrd.kernelModules = ["vmwgfx"];
  services.xserver.videoDrivers = ["vmware"];

  hardware.graphics.enable = true;

  # Wayland/wlroots friendly env in a VM
  environment.sessionVariables = {
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    GBM_BACKENDS_PATH = "/run/opengl-driver/lib/gbm";
    NIXOS_OZONE_WL = "1";
  };

  # XDG portals (not required to boot, but fixes app dialogs/screensharing later)
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
  # If you want to launch straight to Hyprland without GDM,
  # greetd is the simplest. (Comment this out if you’ll use GDM.)
  services.greetd = {
    enable = true;
    settings.default_session = {
      # Start Hyprland under a dbus session
      command = "${pkgs.dbus}/bin/dbus-run-session Hyprland";
      user = "maxpw";
    };
  };
}
