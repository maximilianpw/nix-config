# Linux-specific systemd services and desktop settings
{isWSL ? false, ...}: {
  pkgs,
  lib,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux && !isWSL;
in {
  systemd.user.services.polkit-gnome = lib.mkIf isLinux {
    Unit = {
      Description = "polkit-gnome Authentication Agent";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
    Install = {WantedBy = ["graphical-session.target"];};
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf isLinux {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
