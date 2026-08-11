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
    hosts = import ./lib/inventory.nix {inherit lib;};

    # Overlay to pull select packages from nixpkgs-unstable and add custom packages
    overlays = [
      fenix.overlays.default
      (_: prev: let
        llm = inputs.llm-agents.packages.${prev.stdenv.hostPlatform.system};
        resignBunBinary = package: binaryPath:
          if prev.stdenv.hostPlatform.isDarwin
          then
            package.overrideAttrs (old: {
              # Nix rewrites Bun's Mach-O dependencies during fixup, which
              # invalidates the embedded signature and makes macOS kill it.
              nativeBuildInputs =
                (old.nativeBuildInputs or [])
                ++ [prev.darwin.sigtool];
              postFixup =
                (old.postFixup or "")
                + ''
                  codesign --force --sign - "$out/${binaryPath}"
                '';
            })
          else package;
        hunk = resignBunBinary llm.hunk "bin/hunk";
        pi = resignBunBinary llm.pi "libexec/pi/pi";
      in {
        inherit (llm) claude-code;
        inherit (llm) codex;
        inherit (llm) opencode;
        inherit (llm) grok;
        inherit (llm) herdr;
        amp-cli = llm.amp;
        inherit pi;
        inherit (llm) skills;
        hunkdiff = hunk;
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
        # Home Assistant integrations move on a monthly cadence, so keep Core
        # and its declarative extensions on the same current package set.
        inherit
          (unstable)
          home-assistant
          home-assistant-custom-lovelace-modules
          jujutsu
          zig
          ;
        helium = final.callPackage ./packages/helium.nix {};
        tunarr = final.callPackage ./packages/tunarr.nix {};
        obsidian = final.callPackage ./packages/obsidian.nix {};
        cliproxyapi = final.callPackage ./packages/cliproxyapi.nix {};
        plannotator = final.callPackage ./packages/plannotator.nix {};
        nextcloud-calendar = final.callPackage ./packages/nextcloud-calendar.nix {};
      })
    ];

    mkSystem = import ./lib/mksystem.nix {
      inherit overlays nixpkgs inputs;
    };

    mkConfiguredSystem = name: host:
      mkSystem name {
        inherit (host) darwin linuxDesktop profiles system user userDir wsl;
        hostRecord = host;
        hostInventory = hosts;
        extraModules = map (moduleName: inputs.nixos-hardware.nixosModules.${moduleName}) host.hardwareModules;
      };

    nixosHosts = lib.filterAttrs (_: host: !host.darwin) hosts;
    darwinHosts = lib.filterAttrs (_: host: host.darwin) hosts;
    desktopKim = mkConfiguredSystem "kim" (hosts.kim
      // {
        linuxDesktop = true;
        profiles = hosts.kim.profiles ++ ["desktop"];
      });

    mkPreCommitCheck = system:
      git-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          actionlint.enable = true;
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
        eval-kim = self.nixosConfigurations.kim.config.system.build.toplevel;
        # Keep the parked Hyprland profile evaluable while kim is headless.
        eval-kim-desktop = desktopKim.config.system.build.toplevel;
        eval-cuno = self.nixosConfigurations.cuno.config.system.build.toplevel;
        pre-commit-check = mkPreCommitCheck "x86_64-linux";
        homelab-ingress-regression = import ./tests/homelab-ingress-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        homelab-inventory-regression = import ./tests/homelab-inventory-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        immich-config-regression = import ./tests/immich-config-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        media-stack-regression = import ./tests/media-stack-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = self.nixosConfigurations.kim.pkgs;
        };
        tailscale-serve-regression = import ./tests/tailscale-serve-regression.nix {
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        homelab-backup-regression = import ./tests/homelab-backup-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        paperless-config-regression = import ./tests/paperless-config-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        homepage-calendar-regression = import ./tests/homepage-calendar-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        monitoring-regression = import ./tests/monitoring-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        fleet-agent-forwarding-regression = import ./tests/fleet-agent-forwarding-regression.nix {
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        fleet-ssh-regression = import ./tests/fleet-ssh-regression.nix {
          inherit lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        };
        fleet-ghostty-regression = import ./tests/fleet-ghostty-regression.nix {
          config = self.nixosConfigurations.kim.config;
          inherit lib;
          pkgs = self.nixosConfigurations.kim.pkgs;
        };
        fleet-trust-regression = import ./tests/fleet-trust-regression.nix {
          inherit hosts lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
          configs =
            lib.mapAttrsToList (name: host: {
              config =
                if host.darwin
                then self.darwinConfigurations.${name}.config
                else self.nixosConfigurations.${name}.config;
              inherit (host) user;
              isDarwin = host.darwin;
            })
            hosts;
        };
      };
      aarch64-darwin = {
        eval-joyce = self.darwinConfigurations.joyce.system;
        fleet-ssh-regression = import ./tests/fleet-ssh-regression.nix {
          inherit lib;
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
        };
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
        inherit (pkgs) helium obsidian skills cliproxyapi plannotator nextcloud-calendar hunkdiff nix-update tunarr;
      };
      aarch64-darwin = let
        pkgs = mkPkgs "aarch64-darwin";
      in {
        inherit (pkgs) skills plannotator nextcloud-calendar hunkdiff nix-update;
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
