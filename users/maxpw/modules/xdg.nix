# XDG config file management
{
  config,
  isDarwin,
  isWSL ? false,
  hostname,
  lib,
  pkgs,
  ...
}: let
  isLinux = pkgs.stdenv.isLinux && !isWSL;
  hyprConfigPath = "${config.home.homeDirectory}/nix-config/users/maxpw/hyprland";
  uwsmEnv = ''
    export GDK_SCALE=1.6
    export GDK_DPI_SCALE=1
    export GDK_BACKEND=wayland,x11
    export QT_QPA_PLATFORM='wayland;xcb'
    export MOZ_ENABLE_WAYLAND=1
    export XCURSOR_THEME=Vanilla-DMZ
    export XCURSOR_SIZE=128
  '';

  # Live-link top-level Hyprland entries while allowing generated host overrides.
  symlinkDir = dir: outOfStoreDir: prefix:
    lib.mapAttrs' (name: type: {
      name = "${prefix}/${name}";
      value = {source = config.lib.file.mkOutOfStoreSymlink "${outOfStoreDir}/${name}";};
    }) (lib.filterAttrs (name: _: name != "hyprland.conf") (builtins.readDir dir));

  hasLockScreen = hostname != "main-pc";

  hostLua =
    if hasLockScreen
    then ''
      hl.bind("SUPER + ESCAPE", hl.dsp.exec_cmd("hyprlock"))
    ''
    else "";
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
      if isLinux
      then
        {
          "ghostty/config".text = builtins.readFile ../ghostty.linux;
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
          "helium/NativeMessagingHosts/com.1password.1password.json".text = builtins.toJSON {
            name = "com.1password.1password";
            description = "1Password BrowserSupport";
            path = "/run/wrappers/bin/1Password-BrowserSupport";
            type = "stdio";
            allowed_origins = [
              "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/"
              "chrome-extension://bkpbhnjcbehoklfkljkkbbmipaphipgl/"
              "chrome-extension://dppgmdbiimibapkepcbdbmkaabgiofem/"
              "chrome-extension://gejiddohjgogedgjnonbofjigllpkmbf/"
              "chrome-extension://hjlinigoblmkhjejkmbegnoaljkphmgo/"
              "chrome-extension://khgocmkkpikpnmmkgmdnfckapcdkgfaf/"
            ];
          };
          "net.imput.helium/NativeMessagingHosts/com.1password.1password.json".text = builtins.toJSON {
            name = "com.1password.1password";
            description = "1Password BrowserSupport";
            path = "/run/wrappers/bin/1Password-BrowserSupport";
            type = "stdio";
            allowed_origins = [
              "chrome-extension://aeblfdkhhhdcdjpifhhbdiojplfjncoa/"
              "chrome-extension://bkpbhnjcbehoklfkljkkbbmipaphipgl/"
              "chrome-extension://dppgmdbiimibapkepcbdbmkaabgiofem/"
              "chrome-extension://gejiddohjgogedgjnonbofjigllpkmbf/"
              "chrome-extension://hjlinigoblmkhjejkmbegnoaljkphmgo/"
              "chrome-extension://khgocmkkpikpnmmkgmdnfckapcdkgfaf/"
            ];
          };
        }
        // (symlinkDir ../hyprland hyprConfigPath "hypr")
        // {
          "hypr/host.lua".text = hostLua;
        }
      else {}
    );
}
