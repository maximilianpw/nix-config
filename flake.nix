{
  description = "NixOS configuration flake for VMs and development";

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

  outputs = inputs@{ self, nix-darwin, nixpkgs, nixos-hardware, home-manager, ... }: let
    systems = ["aarch64-linux" "x86_64-linux" "x86_64-darwin"];

    mkSystem = system: hostname: modules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          [
            ./modules/nixos/common.nix
          ]
          ++ modules;
      };
    mkDarwin = hostname: modules:
      nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        modules = modules;
        specialArgs = { inherit inputs; };
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
        ./hosts/mac-darwin/darwin-configuration.nix
      ];
    };

    # Development shell for managing the configuration
    devShells = nixpkgs.lib.genAttrs systems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in
      pkgs.mkShell {
        buildInputs = with pkgs; [
          alejandra
          git
          nixos-rebuild
        ];
        shellHook = ''
          echo "NixOS Configuration Development Shell"
          echo "Use 'alejandra .' to format Nix files"
          echo "Use './scripts/nixos-rebuild.sh <host>' to rebuild"
        '';
      });
  };
}
