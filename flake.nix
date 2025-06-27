{
  description = "Nixos config flake";

  inputs = {
    # Use LTS release (23.11 is LTS)
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    # Support multiple systems with ARM64 priority
    systems = ["aarch64-linux" "x86_64-linux"];
  in {
    nixosConfigurations = import ./hosts inputs;
  };
}
