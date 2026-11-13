# NixOS side of the Wayland desktop: audio, graphics, portals and the groups
# a seat user needs. Hyprland itself is modules/hyprland/nixos.nix.
{
  currentSystemUser,
  pkgs,
  ...
}: {
  hardware.graphics.enable = true;

  # RTK for real-time priority management (needed for PipeWire and audio)
  security.rtkit.enable = true;
  # Polkit for privilege prompts (desktop authentication agent)
  security.polkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    extraConfig.pipewire."99-high-res" = {
      "context.properties" = {
        "default.clock.rate" = 48000;
        "default.clock.allowed-rates" = [44100 48000 88200 96000 176400 192000 352800 384000];
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk];
    config.common.default = ["hyprland" "gtk"];
  };

  users.users.${currentSystemUser}.extraGroups = ["seat" "input" "video"];

  environment = {
    systemPackages = [pkgs.helium];
    sessionVariables.NIXOS_OZONE_WL = "1";
  };
}
