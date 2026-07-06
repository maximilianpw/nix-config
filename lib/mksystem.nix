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
  linuxDesktop ? (!darwin && !wsl),
  extraModules ? [],
}: let
  inherit (nixpkgs) lib;
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

  systemArgs = {
    currentSystem = system;
    currentSystemName = name;
    currentSystemUser = user;
    currentSystemUserDir = userDir;
    isDarwin = darwin;
    isWSL = wsl;
    isLinuxDesktop = linuxDesktop;
    inherit inputs;
  };
in
  systemFunc {
    modules =
      [
        {nixpkgs.hostPlatform = system;}
        {nixpkgs.config.allowUnfree = true;}
        {nixpkgs.overlays = overlays;}
      ]
      ++ lib.optional (!darwin) inputs.sops-nix.nixosModules.sops
      ++ lib.optional wsl inputs.nixos-wsl.nixosModules.wsl
      ++ [
        machineConfig
        userOSConfig
        homeManagerMods.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs =
              systemArgs
              // {
                hostname = name;
              };
            users.${user} = import userHMConfig;
          };
        }
        {
          config._module.args = systemArgs;
        }
      ]
      ++ extraModules;
  }
