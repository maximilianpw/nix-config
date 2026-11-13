{
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

  settings = import ../../users/maxpw/settings.nix {inherit pkgs;};
  # Login shell for session environment, then hand off to the interactive
  # shell (same shape as the old `bash -l -c nu`).
  ghosttyConfig =
    ''
      command = ${lib.getExe settings.loginShell} -l -c ${lib.getExe settings.interactiveShell}
    ''
    + builtins.readFile ../linux-desktop/ghostty.linux;
in {
  xdg.enable = true;

  xdg.configFile = lib.mkIf isLinuxDesktop (
    {"ghostty/config".text = ghosttyConfig;}
    # 1Password browser integration for Helium (Chromium fork). Helium's
    # binary path must also be added to customAllowedBrowsers in the 1Password
    # UI (Settings → Developer); its settings.json is HMAC-signed.
    // heliumNativeMessagingFiles
  );
}
