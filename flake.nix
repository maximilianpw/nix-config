{
  description = "NixOS & Nix-Darwin configuration by @maximilianpw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    fenix,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    nix-darwin,
    ...
  }: let
    # Overlay to pull select packages from nixpkgs-unstable and add custom packages
    overlays = [
      fenix.overlays.default
      (final: prev: let
        llm = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system};
      in {
        claude-code = llm.claude-code;
        codex = llm.codex;
        opencode = llm.opencode;
        amp-cli = llm.amp;
        pi = llm.pi;
        agent-browser = llm.agent-browser;
      })
      (final: prev: let
        unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
      in {
        # Expose the full unstable channel for consumers that need a single
        # unstable package without shadowing the stable one globally (which
        # would force mass rebuilds of everything depending on it).
        inherit unstable;
        # direnv 2.37.1 fish tests get killed during build on macOS (sandbox/OOM)
        direnv = prev.direnv.overrideAttrs (old: {doCheck = false;});
        jujutsu = unstable.jujutsu;
        helium = final.callPackage ./packages/helium.nix {};
        obsidian = final.callPackage ./packages/obsidian.nix {};
        t3code = final.callPackage ./packages/t3code.nix {};
        skills = final.callPackage ./packages/skills.nix {};
        coderabbit = final.callPackage ./packages/coderabbit.nix {};
        hunkdiff = final.callPackage ./packages/hunkdiff.nix {};
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

    nixosConfigurations.wsl = mkSystem "wsl" {
      system = "x86_64-linux";
      user = "maxpw";
      wsl = true;
    };

    darwinConfigurations.macbook-pro-m1 = mkSystem "macbook-pro-m1" {
      system = "aarch64-darwin";
      # macOS login is max-vev but repo directory uses maxpw for shared configs
      user = "max-vev";
      userDir = "maxpw";
      darwin = true;
    };

    templates = {
      generic = {
        path = ./templates/generic;
        description = "Generic Nix devshell with direnv";
      };
      node = {
        path = ./templates/node;
        description = "Node.js project with pnpm";
      };
      rust = {
        path = ./templates/rust;
        description = "Rust project with fenix toolchain";
      };
    };

    # Eval-only checks: catch typos, missing modules, type errors without building
    checks = {
      x86_64-linux = {
        eval-main-pc = self.nixosConfigurations.main-pc.config.system.build.toplevel;
        eval-wsl = self.nixosConfigurations.wsl.config.system.build.toplevel;
      };
      aarch64-darwin = {
        eval-macbook = self.darwinConfigurations.macbook-pro-m1.system;
      };
    };

    # Custom packages exposed as flake outputs so `nix build .#<name>` and
    # `nix-update --flake <name>` can find them. The overlay still injects
    # these into `pkgs.*` for module consumption — this is additive.
    packages = let
      mkPkgs = system:
        import nixpkgs {
          inherit system overlays;
          config.allowUnfree = true;
        };
    in {
      x86_64-linux = let
        pkgs = mkPkgs "x86_64-linux";
      in {
        inherit (pkgs) helium obsidian t3code skills coderabbit hunkdiff;
      };
      aarch64-darwin = let
        pkgs = mkPkgs "aarch64-darwin";
      in {
        inherit (pkgs) skills coderabbit hunkdiff;
      };
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
