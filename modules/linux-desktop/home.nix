# Home Manager side of the Wayland desktop: GUI packages, session services,
# the terminal emulator and the cursor. Hyprland itself is
# modules/hyprland/home.nix.
{
  lib,
  osConfig,
  pkgs,
  ...
}: {
  home.packages = [
    # Terminal emulators
    pkgs.ghostty
    pkgs.kitty

    # Wayland desktop essentials
    pkgs.wl-clipboard
    pkgs.libnotify
    pkgs.zenity

    # GUI applications
    pkgs.nautilus
    pkgs.discord
    pkgs.mongodb-compass
    pkgs.protonmail-desktop
    pkgs.mullvad-vpn
    pkgs.obsidian

    # System utilities
    pkgs.pavucontrol
    pkgs.brightnessctl
    pkgs.playerctl
    pkgs.cava
  ];

  # Login shell for session environment, then hand off to the interactive
  # shell (same shape as the old `bash -l -c nu`).
  xdg.configFile."ghostty/config".text =
    ''
      command = ${lib.getExe osConfig.custom.shells.login} -l -c ${lib.getExe osConfig.custom.shells.interactive}
    ''
    + builtins.readFile ./ghostty.linux;

  services.gnome-keyring = {
    enable = true;
    components = ["secrets"];
  };

  systemd.user.services.polkit-gnome = {
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
  systemd.user.services.protonmail-bridge = {
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
  home.pointerCursor = {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 128;
    x11.enable = true;
  };
}
