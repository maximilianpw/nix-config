# Linux-specific systemd services and desktop settings
{
  isLinuxDesktop,
  pkgs,
  lib,
  ...
}: {
  services.gnome-keyring = lib.mkIf isLinuxDesktop {
    enable = true;
    components = ["secrets"];
  };

  systemd.user.services.polkit-gnome = lib.mkIf isLinuxDesktop {
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

  # Proton Mail Bridge: local IMAP/SMTP gateway that himalaya talks to.
  # Runs headless once you've logged in interactively at least once
  # (`protonmail-bridge --cli` -> `login`). Bridge needs a Secret Service
  # keyring (e.g. gnome-keyring) to persist credentials; if login can't store
  # them, enable a keyring before relying on this unit.
  systemd.user.services.protonmail-bridge = lib.mkIf isLinuxDesktop {
    Unit = {
      Description = "Proton Mail Bridge";
      After = ["graphical-session.target" "gnome-keyring.service"];
      Wants = ["gnome-keyring.service"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      ExecStart = "${pkgs.protonmail-bridge}/bin/protonmail-bridge --noninteractive";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install = {WantedBy = ["graphical-session.target"];};
  };

  # Make cursor not tiny on HiDPI screens
  home.pointerCursor = lib.mkIf isLinuxDesktop {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
