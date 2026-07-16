{
  description = "NixOS & Nix-Darwin configuration by @maximilianpw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-darwin.url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    nixos-wsl.url = "github:nix-community/NixOS-WSL";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nixos-hardware.inputs.nixpkgs.follows = "nixpkgs";

    llm-agents.url = "github:numtide/llm-agents.nix";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    stylix.url = "github:nix-community/stylix/release-26.05";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    self,
    fenix,
    git-hooks,
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;
    hosts = import ./lib/hosts.nix;

    requiredHostFields = [
      "system"
      "user"
      "userDir"
      "darwin"
      "wsl"
      "linuxDesktop"
      "hardwareModules"
      "profiles"
      "role"
      "os"
      "gui"
      "longRunningAgents"
      "fleet"
    ];

    validateHost = name: host:
      lib.assertMsg
      (lib.all (field: builtins.hasAttr field host) requiredHostFields)
      "host '${name}' is missing a required field in lib/hosts.nix"
      && lib.assertMsg
      (lib.isString host.system && lib.isString host.user && lib.isString host.userDir)
      "host '${name}' has invalid system/user fields"
      && lib.assertMsg
      (lib.isBool host.darwin && lib.isBool host.wsl && lib.isBool host.linuxDesktop)
      "host '${name}' has invalid platform flags"
      && lib.assertMsg
      (!(host.darwin && host.wsl) && !(host.darwin && host.linuxDesktop))
      "host '${name}' declares incompatible platform flags"
      && lib.assertMsg
      (lib.isList host.hardwareModules && lib.all lib.isString host.hardwareModules)
      "host '${name}' has invalid hardwareModules"
      && lib.assertMsg
      (lib.isList host.profiles && lib.all lib.isString host.profiles)
      "host '${name}' has invalid profiles";

    # Overlay to pull select packages from nixpkgs-unstable and add custom packages
    overlays = [
      fenix.overlays.default
      (_: prev: let
        llm = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system};
      in {
        inherit (llm) claude-code;
        inherit (llm) codex;
        inherit (llm) opencode;
        amp-cli = llm.amp;
        inherit (llm) pi;
        inherit (llm) skills;
        hunkdiff = llm.hunk;
        inherit (llm) agent-browser;
      })
      (final: prev: let
        unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
      in {
        # Expose the full unstable channel for consumers that need a single
        # unstable package without shadowing the stable one globally (which
        # would force mass rebuilds of everything depending on it).
        inherit unstable;
        # direnv 2.37.1 fish tests get killed during build on macOS (sandbox/OOM)
        direnv = prev.direnv.overrideAttrs (_: {doCheck = false;});
        inherit (unstable) jujutsu;
        inherit (unstable) zig;
        helium = final.callPackage ./packages/helium.nix {};
        obsidian = final.callPackage ./packages/obsidian.nix {};
        coderabbit = final.callPackage ./packages/coderabbit.nix {};
      })
    ];

    mkSystem = import ./lib/mksystem.nix {
      inherit overlays nixpkgs inputs;
    };

    mkConfiguredSystem = name: host:
      assert validateHost name host;
        mkSystem name {
          inherit (host) darwin linuxDesktop profiles system user userDir wsl;
          extraModules = map (moduleName: inputs.nixos-hardware.nixosModules.${moduleName}) host.hardwareModules;
        };

    nixosHosts = lib.filterAttrs (_: host: !host.darwin) hosts;
    darwinHosts = lib.filterAttrs (_: host: host.darwin) hosts;
    desktopMainPc = mkConfiguredSystem "main-pc" (hosts.main-pc
      // {
        linuxDesktop = true;
        profiles = hosts.main-pc.profiles ++ ["desktop"];
      });

    mkPreCommitCheck = system:
      git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          alejandra.enable = true;
          statix.enable = true;
          statix.settings.ignore = ["machines/hardware"];
          deadnix = {
            enable = true;
            excludes = ["machines/hardware/.*"];
            settings.exclude = ["machines/hardware"];
          };
        };
      };
  in {
    # Host outputs and fleet metadata derive from one typed, data-only source.
    lib.hosts = hosts;
    nixosConfigurations = lib.mapAttrs mkConfiguredSystem nixosHosts;
    darwinConfigurations = lib.mapAttrs mkConfiguredSystem darwinHosts;

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

    # Locked reprovisioning tool. The layout itself remains intentionally
    # separate from live mounts and must only be run after a manual disk review.
    apps.x86_64-linux.disko = {
      type = "app";
      program = "${inputs.disko.packages.x86_64-linux.disko}/bin/disko";
    };

    # Eval-only checks: catch typos, missing modules, type errors without building
    checks = {
      x86_64-linux = {
        eval-main-pc = self.nixosConfigurations.main-pc.config.system.build.toplevel;
        # Keep the parked Hyprland profile evaluable while main-pc is headless.
        eval-main-pc-desktop = desktopMainPc.config.system.build.toplevel;
        eval-wsl = self.nixosConfigurations.wsl.config.system.build.toplevel;
        pre-commit-check = mkPreCommitCheck "x86_64-linux";
        tailscale-serve-regression = import ./tests/tailscale-serve-regression.nix {
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
      };
      aarch64-darwin = {
        eval-macbook = self.darwinConfigurations.macbook-pro-m1.system;
        pre-commit-check = mkPreCommitCheck "aarch64-darwin";
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
        inherit (pkgs) helium obsidian skills coderabbit hunkdiff nix-update;
      };
      aarch64-darwin = let
        pkgs = mkPkgs "aarch64-darwin";
      in {
        inherit (pkgs) skills coderabbit hunkdiff nix-update;
      };
    };

    formatter = nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux" "aarch64-darwin"] (
      system: nixpkgs.legacyPackages.${system}.alejandra
    );

    devShells = nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux" "aarch64-darwin"] (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [git nix shellcheck];
        shellHook = ''
          ${self.checks.${system}.pre-commit-check.shellHook or ""}
          echo "Welcome to the Nix dev shell for ${system}"
        '';
      };
    });
  };
}
