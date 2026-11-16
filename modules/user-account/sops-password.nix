# NixOS module for hosts whose login password comes from sops (see
# secrets/README.md).
{
  config,
  currentSystemUser,
  lib,
  pkgs,
  ...
}: let
  loginShell = config.custom.shells.login;
in {
  sops.secrets.maxpw-password.neededForUsers = true;

  users = {
    defaultUserShell = loginShell;
    users.${currentSystemUser}.hashedPasswordFile = config.sops.secrets.maxpw-password.path;
  };

  system.activationScripts.ensureUserLoginShell = {
    deps = ["users"];
    # mutableUsers can preserve a stale passwd shell across rebuilds.
    text = ''
      ${pkgs.shadow}/bin/usermod --shell ${lib.getExe loginShell} ${lib.escapeShellArg currentSystemUser}
    '';
  };
}
