{
  nixpkgs,
  overlays,
  inputs,
}: name: {
  system,
  user,
  # The directory holding the user configs, which may differ from the
  # on-system login name (e.g. "max-vev" uses "maxpw").
  userDir,
  darwin,
  wsl,
  linuxDesktop,
  hostRecord,
  hostInventory,
  extraModules,
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
    currentSystemName = name;
    currentSystemUser = user;
    currentSystemUserDir = userDir;
    isDarwin = darwin;
    isWSL = wsl;
    isLinuxDesktop = linuxDesktop;
    inherit hostInventory hostRecord inputs;
  };
in
  systemFunc {
    modules =
      [
        {nixpkgs.hostPlatform = system;}
        {nixpkgs.config.allowUnfree = true;}
        {nixpkgs.overlays = overlays;}
      ]
      ++ lib.optional darwin inputs.sops-nix.darwinModules.sops
      ++ lib.optional (!darwin) inputs.sops-nix.nixosModules.sops
      ++ lib.optional wsl inputs.nixos-wsl.nixosModules.wsl
      ++ lib.optional (!darwin) inputs.fleet.nixosModules.cliproxy-quota
      # Imported here because homelab modules receive inputs through
      # _module.args, which cannot feed `imports`.
      ++ lib.optional (hostRecord.role == "nixos-homelab") inputs.superlocal.nixosModules.default
      ++ lib.optionals hostRecord.hjem [
        (
          if darwin
          then inputs.hjem.darwinModules.default
          else inputs.hjem.nixosModules.default
        )
        ../users/${userDir}/hjem
      ]
      ++ lib.optional (hostRecord.hjem && darwin) ../users/${userDir}/hjem/darwin.nix
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
