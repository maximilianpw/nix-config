{
  desktopKim,
  hosts,
  inputs,
  lib,
  mkPreCommitCheck,
  nixpkgs,
  nvim,
  self,
}: {
  x86_64-linux = {
    git-merge-regression = import ../tests/git-merge-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      home = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
    };
    # Upstream runs tests in the package build and memory-heavy lint separately.
    leerr-package = inputs.leerr.packages.x86_64-linux.default;
    leerr-lint = inputs.leerr.checks.x86_64-linux.lint;
    t3code-package = import ../tests/t3code-package-check.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      package = self.packages.x86_64-linux.t3code;
    };
    t3code-config-regression = import ../tests/t3code-config-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      linuxPackage = self.packages.x86_64-linux.t3code;
      kim = self.nixosConfigurations.kim.config;
      joyce = self.darwinConfigurations.joyce.config;
      cuno = self.nixosConfigurations.cuno.config;
    };
    eval-kim = self.nixosConfigurations.kim.config.system.build.toplevel;
    # Keep the parked Hyprland profile evaluable while kim is headless.
    eval-kim-desktop = desktopKim.config.system.build.toplevel;
    eval-cuno = self.nixosConfigurations.cuno.config.system.build.toplevel;
    nvim-candidate = (nvim "x86_64-linux").nvim-candidate-check;
    nvim-stable = (nvim "x86_64-linux").nvim-stable-check;
    hjem-lifecycle-regression = import ../tests/hjem-lifecycle-regression.nix {
      inherit (inputs) hjem;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
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
      fleetPackages = inputs.fleet.packages;
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
    media-companions-regression = import ../tests/media-companions-regression.nix {
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
    homepage-regression = import ../tests/homepage-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    nextcloud-apps-regression = import ../tests/nextcloud-apps-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    template-regression = import ../tests/template-regression.nix {
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
    morning-report-regression = import ../tests/morning-report-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      kim = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
      cuno = self.nixosConfigurations.cuno.config.home-manager.users.maxpw;
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
    git-merge-regression = import ../tests/git-merge-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      home = self.darwinConfigurations.joyce.config.home-manager.users.max-vev;
    };
    t3code-package = import ../tests/t3code-package-check.nix {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      package = self.packages.aarch64-darwin.t3code;
    };
    eval-joyce = self.darwinConfigurations.joyce.system;
    nvim-candidate = (nvim "aarch64-darwin").nvim-candidate-check;
    nvim-stable = (nvim "aarch64-darwin").nvim-stable-check;
    hjem-lifecycle-regression = import ../tests/hjem-lifecycle-regression.nix {
      inherit (inputs) hjem;
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    };
    pre-commit-check = mkPreCommitCheck "aarch64-darwin";
  };
}
