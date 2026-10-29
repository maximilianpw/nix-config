{
  # Public, inert stand-in. Only the CI helper overrides the private input.
  description = "CI stub for the private homelab-mcp flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

  outputs = {nixpkgs, ...}: {
    packages.x86_64-linux.homelab-mcp = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
      (pkgs.writeShellScriptBin "homelab-mcp" "exit 1") // {version = "0.0.0-ci-stub";};
  };
}
