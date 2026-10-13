{
  currentSystemUser,
  pkgs,
  lib,
  ...
}: {
  # Finder/Dock launches bypass the package's bin/t3code wrapper. Set the
  # documented updater opt-out in the GUI session without modifying Info.plist.
  launchd.user.envVariables.T3CODE_DISABLE_AUTO_UPDATE = "1";

  # Homebrew cleanup is zap. Never let it remove a retired T3 cask and its
  # userdata implicitly: the operator must do the non-zapping handover first.
  system.activationScripts.preActivation.text = lib.mkBefore ''
    T3CODE_SYSTEM_USER=${lib.escapeShellArg currentSystemUser} \
      ${lib.getExe pkgs.bash} ${../../../scripts/t3code-pre-activation.sh}
  '';
}
