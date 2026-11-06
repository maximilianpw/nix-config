{
  isDarwin,
  isLinuxDesktop,
  lib,
  pkgs,
  ...
}: let
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

          # 1Password browser integration for Helium (Chromium fork).
          # Must also add Helium's binary path to customAllowedBrowsers via
          # the 1Password UI (Settings → Developer) — settings.json is
          # HMAC-signed so it cannot be set declaratively.
        }
        // heliumNativeMessagingFiles
      else {}
    );
}
