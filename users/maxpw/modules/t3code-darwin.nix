{
  currentSystemUser,
  pkgs,
  lib,
  ...
}: {
  # Disable in-app updates for the Nix-owned, source-built desktop, including
  # Finder/Dock launches, without modifying the upstream package.
  launchd.user.envVariables.T3CODE_DISABLE_AUTO_UPDATE = "1";

  # Homebrew cleanup is zap. Never let it remove a retired T3 cask and its
  # userdata implicitly: the operator must do the non-zapping handover first.
  system.activationScripts.preActivation.text = lib.mkBefore ''
    T3CODE_SYSTEM_USER=${lib.escapeShellArg currentSystemUser} \
      ${lib.getExe pkgs.bash} ${../../../scripts/t3code-pre-activation.sh}
  '';
}
