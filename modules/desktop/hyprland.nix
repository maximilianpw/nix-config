{
  inputs,
  pkgs,
  lib,
  config,
  currentSystemUser ? "maxpw",
  ...
}: let
  cfg = config.custom.hyprland;
  homeDir = config.users.users.${currentSystemUser}.home;
in {
  options.custom.hyprland = {
    enable = lib.mkEnableOption "Hyprland with greetd";

    greeterCommand = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'start-hyprland -- --config ${homeDir}/.config/hypr/hyprland.lua'";
      description = "Greeter command for greetd";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      withUWSM = true;
      xwayland.enable = true;
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = cfg.greeterCommand;
          user = "greeter";
        };
      };
    };
  };
}
