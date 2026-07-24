# XDG config file management
{
  config,
  isDarwin,
  isLinuxDesktop,
  currentSystemUserDir,
  hostname,
  lib,
  pkgs,
  ...
}: let
  homeFiles = import ../../../lib/home-files.nix {
    inherit lib;
    mkOutOfStoreSymlink = config.lib.file.mkOutOfStoreSymlink;
  };

  hyprConfigPath = "${config.home.homeDirectory}/nix-config/users/${currentSystemUserDir}/hyprland";
  uwsmEnv = ''
    export GDK_SCALE=1.6
    export GDK_DPI_SCALE=1
    export GDK_BACKEND=wayland,x11
    export QT_QPA_PLATFORM='wayland;xcb'
    export MOZ_ENABLE_WAYLAND=1
    export XCURSOR_THEME=Vanilla-DMZ
    export XCURSOR_SIZE=128
  '';

  hasLockScreen = hostname != "kim";

  hostLua =
    if hasLockScreen
    then ''
      hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("hyprlock"))
    ''
    else "";

  hypridleConfig =
    if hasLockScreen
    then ''
      listener {
        timeout = 600
        on-timeout = hyprlock
      }

      listener {
        timeout = 900
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
      }

      listener {
        timeout = 3600
        on-timeout = systemctl hibernate
      }
    ''
    else ''
      listener {
        timeout = 900
        on-timeout = hyprctl dispatch dpms off
        on-resume = hyprctl dispatch dpms on
      }
    '';

  onePasswordAllowedOrigins = [
    "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/"
    "chrome-extension://bkpbhnjcbehoklfkljkkbbmipaphipgl/"
    "chrome-extension://dppgmdbiimibapkepcbdbmkaabgiofem/"
    "chrome-extension://gejiddohjgogedgjnonbofjigllpkmbf/"
    "chrome-extension://hjlinigoblmkhjejkmbegnoaljkphmgo/"
    "chrome-extension://khgocmkkpikpnmmkgmdnfckapcdkgfaf/"
  ];

  onePasswordNativeMessagingHost = builtins.toJSON {
    name = "com.1password.1password";
    description = "1Password BrowserSupport";
    path = "/run/wrappers/bin/1Password-BrowserSupport";
    type = "stdio";
    allowed_origins = onePasswordAllowedOrigins;
  };

  heliumNativeMessagingFiles = lib.genAttrs [
    "helium/NativeMessagingHosts/com.1password.1password.json"
    "net.imput.helium/NativeMessagingHosts/com.1password.1password.json"
  ] (_: {text = onePasswordNativeMessagingHost;});

  settings = import ../settings.nix {inherit pkgs;};
  # Login shell for session environment, then hand off to the interactive
  # shell (same shape as the old `bash -l -c nu`).
  ghosttyConfig =
    ''
      command = ${lib.getExe settings.loginShell} -l -c ${lib.getExe settings.interactiveShell}
    ''
    + builtins.readFile ../ghostty.linux;
in {
  xdg.enable = true;

  xdg.configFile =
    {
      "yazi".source = ../yazi;
      "yazi".recursive = true;
    }
    // (
      if isDarwin
      then {
        # Rectangle.app. This has to be imported manually using the app.
        "rectangle/RectangleConfig.json".text = builtins.readFile ../RectangleConfig.json;
      }
      else {}
    )
    // (
      if isLinuxDesktop
      then
        {
          "ghostty/config".text = ghosttyConfig;
          "gammastep/config.ini".text = builtins.readFile ../config.gammastep;
          "uwsm/env".text = uwsmEnv;
          "rofi".source = ../rofi;
          "rofi".recursive = true;
          "waybar".source = ../waybar;
          "waybar".recursive = true;
          "swaync".source = ../swaync;
          "swaync".recursive = true;
          "wlogout/layout".source = ../wlogout/layout;
          "wlogout/colors.css".source = ../wlogout/colors.css;
          "wlogout/style.css".text =
            builtins.replaceStrings
            ["@WLOGOUT_ICONS@"]
            ["${pkgs.wlogout}/share/wlogout/icons"]
            (builtins.readFile ../wlogout/style.css);

          # 1Password browser integration for Helium (Chromium fork).
          # Must also add Helium's binary path to customAllowedBrowsers via
          # the 1Password UI (Settings → Developer) — settings.json is
          # HMAC-signed so it cannot be set declaratively.
        }
        // heliumNativeMessagingFiles
        // (homeFiles.symlinkDir {
          dir = ../hyprland;
          outOfStoreDir = hyprConfigPath;
          prefix = "hypr";
          exclude = ["hyprland.conf"];
        })
        // {
          "hypr/host.lua".text = hostLua;
          "hypr/hypridle.conf".text = hypridleConfig;
        }
      else {}
    );
}
