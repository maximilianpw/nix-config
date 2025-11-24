{
  description = "NixOS & Nix-Darwin configuration by @maximilianpw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    nix-snapd.url = "github:nix-community/nix-snapd";
    nix-snapd.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";
    jujutsu.url = "github:jj-vcs/jj";

    fish-fzf.url = "github:jethrokuan/fzf/24f4739fc1dffafcc0da3ccfbbd14d9c7d31827a";
    fish-fzf.flake = false;
    fish-foreign-env.url = "github:oh-my-fish/plugin-foreign-env/dddd9213272a0ab848d474d0cbde12ad034e65bc";
    fish-foreign-env.flake = false;
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
      inputs.jujutsu.overlays.default
      (final: prev: {
        unstable = import inputs.nixpkgs-unstable {
          inherit (prev) system;
          config.allowUnfree = true;
        };

        gh = final.unstable.gh;
        claude-code = final.unstable.claude-code;
        gemini-cli = final.unstable.gemini-cli;
        nushell = final.unstable.nushell;
        helium = final.callPackage ./packages/helium.nix {};
      })
    ];

    mkSystem = import ./lib/mksystem.nix {
      inherit overlays nixpkgs inputs;
    };
  in {
    nixosConfigurations.main-pc = mkSystem "main-pc" {
      system = "x86_64-linux";
      user = "maxpw";
    };

    darwinConfigurations.macbook-pro-m1 = mkSystem "macbook-pro-m1" {
      system = "aarch64-darwin";
      # macOS login is max-vev but repo directory uses maxpw for shared configs
      user = "max-vev";
      userDir = "maxpw";
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
