{
  nixpkgs,
  self,
  ...
}: let
  inherit (self) inputs;
  nvidia = ../modules/nixos/nvidia.nix;
  # Remove dotfiles from here since it's now a Home Manager module
in {
  default = nixpkgs.lib.nixosSystem {
    specialArgs = {inherit inputs;};

    modules = [
      ./default/configuration.nix
      inputs.home-manager.nixosModules.default
      nvidia
    ];
  };
  bigboy = nixpkgs.lib.nixosSystem {
    specialArgs = {inherit inputs;};
    modules = [
      ./bigboy/configuration.nix
      inputs.home-manager.nixosModules.default
      nvidia
    ];
  };
  mac = nixpkgs.lib.nixosSystem {
    system = "aarch64-linux"; # Explicitly set ARM64 system
    specialArgs = {inherit inputs;};
    modules = [
      ./mac/configuration.nix
      inputs.home-manager.nixosModules.default
      # dotfiles is now imported in individual user configs
    ];
  };
}
