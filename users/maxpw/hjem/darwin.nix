# Hjem's nix-darwin module always runs a `link-nix-apps` launch agent that links
# every app in the per-user profile into ~/Applications/Nix User Apps. That is
# the only linker for those apps: Home Manager's linkApps/copyApps would add a
# second copy of the same apps under ~/Applications/Home Manager Apps. Another
# module setting either to true fails evaluation as a conflicting definition.
{currentSystemUser, ...}: {
  home-manager.users.${currentSystemUser}.targets.darwin = {
    linkApps.enable = false;
    copyApps.enable = false;
  };
}
