{
  isLinuxDesktop,
  hostname,
  pkgs,
  lib,
  ...
}: {
  # The hermes-desktop package ships only a binary (no XDG entry), so it won't
  # appear in `rofi -show drun` without this. Generates the .desktop file into
  # the profile; rofi picks it up automatically.
  xdg.desktopEntries = lib.mkIf isLinuxDesktop {
    hermes-desktop = {
      name = "Hermes Agent";
      genericName = "AI Agent";
      exec = "hermes-desktop";
      terminal = false;
      categories = ["Utility" "Development"];
    };
  };

  home.packages =
    lib.optionals isLinuxDesktop [
      # App launcher
      pkgs.rofi

      # Terminal emulators
      pkgs.ghostty
      pkgs.kitty

      # Wayland desktop essentials
      pkgs.waybar
      pkgs.wl-clipboard
      pkgs.cliphist
      pkgs.grim
      pkgs.slurp
      pkgs.hyprpaper
      pkgs.hypridle
      pkgs.swaynotificationcenter
      pkgs.gammastep
      pkgs.wlogout
      pkgs.networkmanagerapplet

      # GUI applications
      pkgs.nautilus
      pkgs.discord
      pkgs.mongodb-compass
      pkgs.protonmail-desktop
      pkgs.mullvad-vpn
      pkgs.obsidian
      pkgs.t3code
      pkgs.hermes-desktop # Hermes Agent native desktop app (Nous Research)

      # System utilities
      pkgs.pavucontrol
      pkgs.brightnessctl
      pkgs.playerctl
      pkgs.cava

      # Focus existing window or launch app (used by hyper key bindings)
      (pkgs.writeShellScriptBin "focus-or-launch" ''
        class="$1"
        shift

        if hyprctl clients | ${pkgs.gawk}/bin/awk -v class="$class" '
          $1 == "class:" {
            $1 = ""
            sub(/^ /, "")
            if ($0 == class) found = 1
          }
          END { exit found ? 0 : 1 }
        '; then
          hyprctl dispatch focuswindow "class:$class"
        else
          exec "$@"
        fi
      '')
    ]
    ++ lib.optionals (isLinuxDesktop && hostname != "main-pc") [
      pkgs.hyprlock
    ];
}
