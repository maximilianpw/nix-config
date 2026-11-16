{
  nixpkgs,
  overlays,
  inputs,
  hostInventory,
}: name: host: let
  inherit (nixpkgs) lib;
  inherit (host) darwin wsl user;
  isHomelab = host.role == "nixos-homelab";

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
    isDarwin = darwin;
    isWSL = wsl;
    isLinuxDesktop = host.linuxDesktop;
    hostRecord = host;
    inherit hostInventory inputs;
    homelab = import ../homelab/inventory {inherit lib;};
    template = import ./template.nix {inherit lib;};
  };
in
  systemFunc {
    modules =
      [
        {nixpkgs.hostPlatform = host.system;}
        {nixpkgs.config.allowUnfree = true;}
        {nixpkgs.overlays = overlays;}
      ]
      ++ lib.optional darwin inputs.sops-nix.darwinModules.sops
      ++ lib.optional (!darwin) inputs.sops-nix.nixosModules.sops
      ++ lib.optional wsl inputs.nixos-wsl.nixosModules.wsl
      ++ lib.optional (!darwin) inputs.fleet.nixosModules.cliproxy-quota
      # Imported here because modules receive inputs through _module.args,
      # which cannot feed `imports`.
      ++ lib.optional isHomelab inputs.portfolio-tracker.nixosModules.default
      ++ lib.optional isHomelab inputs.rex.nixosModules.default
      ++ [
        (
          if darwin
          then inputs.hjem.darwinModules.default
          else inputs.hjem.nixosModules.default
        )
        ../machines/${name}.nix
        ../profiles/${host.role}.nix
      ]
      ++ lib.optional host.linuxDesktop ../profiles/linux-desktop.nix
      ++ [
        homeManagerMods.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            extraSpecialArgs = systemArgs;
            # One user configuration even where the login account differs
            # (Joyce's is max-vev).
            users.${user} = import ../users/maxpw/home.nix;
          };
        }
        {
          config._module.args = systemArgs;
        }
      ]
      ++ map (moduleName: inputs.nixos-hardware.nixosModules.${moduleName}) host.hardwareModules;
  }
