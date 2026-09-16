{
  currentSystemUser,
  lib,
  ...
}: let
  cliProxy = import ./config.nix;
  legacyLabel = "org.nixos.cliproxyapi";
  legacyPlist = "/Users/${currentSystemUser}/Library/LaunchAgents/${legacyLabel}.plist";
in {
  # Darwin clients use Kim's public CLIProxyAPI endpoint. Keep the token in a
  # runtime-only sops file so it never enters the Nix store or generated config.
  sops.secrets."cliproxyapi-public-api-key" = {
    owner = currentSystemUser;
    mode = "0400";
  };

  # GUI applications and launchd-owned agent sessions do not source the Home
  # Manager shell environment. Publish only the endpoint and runtime secret
  # path so newly launched Pi processes receive the same explicit routing.
  launchd.user.envVariables = {
    CLIPROXYAPI_ROOT_URL = cliProxy.publicBaseUrl;
    CLIPROXYAPI_API_KEY_FILE = cliProxy.publicApiKeyPath;
  };

  # Removing a nix-darwin LaunchAgent declaration does not unload an agent from
  # an older generation. Stop and remove the obsolete local proxy so missing
  # client routing cannot silently fall back to 127.0.0.1:8317.
  system.activationScripts.postActivation.text = lib.mkOrder 1600 ''
    user_uid=$(/usr/bin/id -u ${lib.escapeShellArg currentSystemUser})
    /bin/launchctl bootout "gui/$user_uid/${legacyLabel}" 2>/dev/null || true
    /bin/rm -f ${lib.escapeShellArg legacyPlist}
  '';
}
