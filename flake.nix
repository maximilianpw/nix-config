{
  description = "NixOS configuration flake for VMs and development";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = {
    self,
    nixpkgs,
    nixos-hardware,
    home-manager,
    ...
  } @ inputs: let
    systems = ["aarch64-linux" "x86_64-linux" "x86_64-darwin"];

    # Helper function to create system configurations
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
  in {
    nixosConfigurations = {
      # Default VM configuration (x86_64)
      default = mkSystem "x86_64-linux" "nixos-default" [
        ./hosts/default/configuration.nix
        ./modules/nixos/vm-common.nix
      ];

      # High-performance VM with NVIDIA (x86_64)
      bigboy = mkSystem "x86_64-linux" "nixos-bigboy" [
        ./hosts/bigboy/configuration.nix
        ./modules/nixos/vm-common.nix
        ./modules/nixos/nvidia.nix
      ];

      # ARM64 VM for Mac (VMware Fusion)
      mac = mkSystem "aarch64-linux" "nixos-mac" [
        ./hosts/mac/configuration.nix
#       ./modules/nixos/vmware.nix
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
