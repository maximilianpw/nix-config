{
  description = "NixOS and nix-darwin configuration flake with devShell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ghostty = {
      url = "github:ghostty-org/ghostty";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    nix-darwin,
    nixpkgs,
    nixos-hardware,
    home-manager,
    ...
  }: let
    systems = ["aarch64-linux" "x86_64-linux" "aarch64-darwin"];

    mkSystem = system: hostname: modules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          [
            #./modules/nixos/nixos-common.nix
          ]
          ++ modules;
      };

    mkDarwin = hostname: modules:
      nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = modules;
        specialArgs = {inherit inputs;};
      };
  in {
    nixosConfigurations = {
      mac-vm = mkSystem "aarch64-linux" "nixos-mac" [
        ./hosts/mac-vm/configuration.nix
        ./modules/nixos/vmware.nix
      ];
    };

    darwinConfigurations = {
      mac-darwin = mkDarwin "mac-darwin" [
        inputs.home-manager.darwinModules.home-manager
        {
          lib.mkDefault = "/Users/max-vev/";
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
          };
        }
        ./hosts/mac-darwin/darwin-configuration.nix
      ];
    };

    # DevShells with correct 'default' attribute per system
    devShells = nixpkgs.lib.genAttrs systems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          buildInputs = with pkgs; [
            alejandra
            git
            nixos-rebuild
          ];

          shellHook = ''
            echo "Nix Configuration Development Shell"
            echo "Use 'alejandra .' to format Nix files"
            echo "Use './scripts/nixos-rebuild.sh <host>' to rebuild"
          '';
        };
      }
    );
  };
}
