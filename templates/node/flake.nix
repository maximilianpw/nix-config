{
  description = "Node.js development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {nixpkgs, ...}: let
    forAllSystems = nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux" "aarch64-darwin"];
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          nodejs_22
          pnpm
          nodePackages.typescript
          nodePackages.typescript-language-server
        ];
      };
    });
  };
}
