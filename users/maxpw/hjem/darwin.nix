# Hjem's nix-darwin module always runs a `link-nix-apps` launch agent that links
# every app in the per-user profile into ~/Applications/Nix User Apps. That is
# the only linker for those apps: Home Manager's linkApps/copyApps would add a
# second copy of the same apps under ~/Applications/Home Manager Apps. Another
# module setting either to true fails evaluation as a conflicting definition.
#
# ./darwin-files holds macOS-only app files, laid out like ./files. Rectangle
# reads its JSON only through the app's manual import.
{
  currentSystemUser,
  lib,
  ...
}: {
  home-manager.users.${currentSystemUser}.targets.darwin = {
    linkApps.enable = false;
    copyApps.enable = false;
  };

  hjem.users.${currentSystemUser}.files = lib.genAttrs (
    map (file: lib.removePrefix "${toString ./darwin-files}/" (toString file)) (lib.filesystem.listFilesRecursive ./darwin-files)
  ) (path: {source = ./darwin-files + "/${path}";});
}
