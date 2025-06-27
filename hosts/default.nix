{
  nixpkgs,
  self,
  ...
}: let
  inherit (self) inputs;
  nvidia = ../modules/nixos/nvidia.nix;
  dotfiles = ../modules/nixos/dotfiles.nix;
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
    specialArgs = {inherit inputs;};
    modules = [
      ./mac/configuration.nix
      inputs.home-manager.nixosModules.default
      dotfiles
    ];
  };
}
