{
  desktopKim,
  hosts,
  inputs,
  lib,
  mkPreCommitCheck,
  nixpkgs,
  self,
}: {
  x86_64-linux = {
    eval-kim = self.nixosConfigurations.kim.config.system.build.toplevel;
    # Keep the parked Hyprland profile evaluable while kim is headless.
    eval-kim-desktop = desktopKim.config.system.build.toplevel;
    eval-cuno = self.nixosConfigurations.cuno.config.system.build.toplevel;
    pre-commit-check = mkPreCommitCheck "x86_64-linux";
    actual-config-regression = import ../tests/actual-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    atuin-config-regression = import ../tests/atuin-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      joyce = self.darwinConfigurations.joyce.config;
      cuno = self.nixosConfigurations.cuno.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    executor-config-regression = import ../tests/executor-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    homelab-ingress-regression = import ../tests/homelab-ingress-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    homelab-inventory-regression = import ../tests/homelab-inventory-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    immich-config-regression = import ../tests/immich-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    media-stack-regression = import ../tests/media-stack-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = self.nixosConfigurations.kim.pkgs;
    };
    tailscale-serve-regression = import ../tests/tailscale-serve-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    homelab-backup-regression = import ../tests/homelab-backup-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    paperless-config-regression = import ../tests/paperless-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    homepage-calendar-regression = import ../tests/homepage-calendar-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    monitoring-regression = import ../tests/monitoring-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    fleet-rust-regression = import ../tests/fleet-rust-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      fleetSrc = inputs.fleet;
      homeManager = inputs.home-manager;
    };
    fleet-installed-regression = import ../tests/fleet-installed-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      fleetPackages = inputs.fleet.packages;
      kim = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
      joyce = self.darwinConfigurations.joyce.config.home-manager.users.max-vev;
    };
    fleet-ghostty-regression = import ../tests/fleet-ghostty-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = self.nixosConfigurations.kim.pkgs;
    };
    fleet-trust-regression = import ../tests/fleet-trust-regression.nix {
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
    pre-commit-check = mkPreCommitCheck "aarch64-darwin";
  };
}
