{
  # Public stand-in for the private homelab-mcp input, used only by CI through
  # `nix flake lock --override-input homelab-mcp path:./tests/stubs/homelab-mcp`.
  # CI has no SSH access to the repository and pushes Kim's builds to a public
  # Cachix cache. Mirror the outputs homelab/media-mcp.nix consumes when they
  # change; the binary is inert.
  description = "CI stub for the private homelab-mcp flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = {nixpkgs, ...}: {
    packages = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"] (system: {
      homelab-mcp = (nixpkgs.legacyPackages.${system}.writeShellScriptBin "homelab-mcp" "exit 1").overrideAttrs {
        version = "0.0.0-ci-stub";
      };
    });
  };
}
