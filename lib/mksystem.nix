{
  nixpkgs,
  overlays,
  inputs,
}: name: {
  system,
  user,
  # Optionally specify a different directory name that holds the user configs.
  # This allows the on-system login/user name (e.g. "max-vev") to differ from
  # the repository directory (e.g. "maxpw"). Defaults to the user name.
  userDir ? user,
  darwin ? false,
  wsl ? false,
}: let
  machineConfig = ../machines/${name}.nix;
  userOSConfig =
    ../users/${userDir}/${
      if darwin
      then "darwin"
      else if wsl
      then "wsl"
      else "nixos"
    }.nix;
  userHMConfig = ../users/${userDir}/home-manager.nix;

  systemFunc =
    if darwin
    then inputs.nix-darwin.lib.darwinSystem
    else nixpkgs.lib.nixosSystem;
  homeManagerMods =
    if darwin
    then inputs.home-manager.darwinModules
    else inputs.home-manager.nixosModules;
in
  systemFunc {
    modules = [
      {nixpkgs.hostPlatform = system;}
      {nixpkgs.config.allowUnfree = true;}
      {nixpkgs.overlays = overlays;}
      (
        if !darwin
        then inputs.sops-nix.nixosModules.sops
        else {}
      )
      (
        if wsl
        then inputs.nixos-wsl.nixosModules.wsl
        else {}
      )
      machineConfig
      userOSConfig
      homeManagerMods.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "backup";
        home-manager.users.${user} = import userHMConfig {
          isDarwin = darwin;
          isWSL = wsl;
          inputs = inputs;
        };
      }
      {
        config._module.args = {
          currentSystem = system;
          currentSystemName = name;
          currentSystemUser = user;
          currentSystemUserDir = userDir;
          isWSL = wsl;
          inputs = inputs;
        };
      }
    ];
  }
