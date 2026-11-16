# 1Password browser integration for Helium (Chromium fork). Helium's binary
# path must also be added to customAllowedBrowsers in the 1Password UI
# (Settings → Developer); its settings.json is HMAC-signed.
{lib, ...}: let
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
in {
  xdg.configFile = lib.genAttrs [
    "helium/NativeMessagingHosts/com.1password.1password.json"
    "net.imput.helium/NativeMessagingHosts/com.1password.1password.json"
  ] (_: {text = onePasswordNativeMessagingHost;});
}
