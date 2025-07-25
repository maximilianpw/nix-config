{
  description = "NixOS & Nix-Darwin configuration by @maximilian-pinder-white";

  inputs = {
    # Primary stable nixpkgs for system configurations
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    # Unstable nixpkgs for bleeding-edge packages if needed
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Build a custom WSL installer
    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    # snapd
    nix-snapd.url = "github:nix-community/nix-snapd";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";

    # Home-Manager for per-user settings
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nix-Darwin for macOS configurations
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Custom overlays (e.g., jujutsu)
    # commented because of issues with gpg tests when building
    # jujutsu.url = "github:jj-vcs/jj";
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    nix-darwin,
    ...
  }: let
    overlays = [
      #inputs.jujutsu.overlays.default

      (final: prev: rec {
        unstable = import inputs.nixpkgs-unstable {
          inherit (prev) system;
          config.allowUnfree = true;
        };

        gh = unstable.gh;
        claude-code = unstable.claude-code;
        nushell = unstable.nushell;
      })
    ];

    mkSystem = import ./lib/mksystem.nix {
      inherit overlays nixpkgs inputs;
    };
  in {
    nixosConfigurations.vm-aarch64 = mkSystem "vm-aarch64" {
      system = "aarch64-linux";
      user = "maxpw";
    };

    darwinConfigurations.macbook-pro-m1 = mkSystem "macbook-pro-m1" {
      system = "aarch64-darwin";
      user = "max-vev";
      darwin = true;
    };

    devShells = nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux" "aarch64-darwin"] (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [git nix];
        shellHook = ''
          echo "Welcome to the Nix dev shell for ${system}"
        '';
      };
    });
  };
}
