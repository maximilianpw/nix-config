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
    herdr-core-package = self.packages.x86_64-linux.herdr-core;
    herdr-config-regression = import ./herdr-config-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      core = self.nixosConfigurations.kim.pkgs.herdr-core;
      package = inputs.herdr-jj.packages.x86_64-linux.default;
      home = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
      files = self.nixosConfigurations.kim.config.hjem.users.maxpw.files;
    };
    herdr-cuno-config-regression = import ./herdr-config-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      core = self.nixosConfigurations.cuno.pkgs.herdr-core;
      package = inputs.herdr-jj.packages.x86_64-linux.default;
      home = self.nixosConfigurations.cuno.config.home-manager.users.maxpw;
      files = self.nixosConfigurations.cuno.config.hjem.users.maxpw.files;
    };
    plannotator-config-regression = import ./plannotator-config-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      version = self.nixosConfigurations.kim.pkgs.plannotator.version;
      kim = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
      joyce = self.darwinConfigurations.joyce.config.home-manager.users.max-vev;
      cuno = self.nixosConfigurations.cuno.config.home-manager.users.maxpw;
    };
    opencode-config-regression = import ./opencode-config-regression.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      package = self.nixosConfigurations.kim.pkgs.opencode;
      plannotatorVersion = self.nixosConfigurations.kim.pkgs.plannotator.version;
      home = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
    };
    git-merge-regression = import ./git-merge-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      home = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
    };
    jujutsu-workflow-regression = import ./jujutsu-workflow-regression.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      home = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
      stackPackage = self.packages.x86_64-linux.jj-stack;
    };
    # Upstream runs tests in the package build and memory-heavy lint separately.
    leerr-package = inputs.leerr.packages.x86_64-linux.default;
    leerr-lint = inputs.leerr.checks.x86_64-linux.lint;
    t3code-package = import ./t3code-package-check.nix {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      package = self.packages.x86_64-linux.t3code;
    };
    t3code-config-regression = import ./t3code-config-regression.nix {
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
    hjem-lifecycle-regression = import ./hjem-lifecycle-regression.nix {
      inherit (inputs) hjem;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    pre-commit-check = mkPreCommitCheck "x86_64-linux";
    actual-config-regression = import ./actual-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      expectedPackage = inputs.nixpkgs-unstable.legacyPackages.x86_64-linux.actual-server;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    atuin-config-regression = import ./atuin-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      joyce = self.darwinConfigurations.joyce.config;
      cuno = self.nixosConfigurations.cuno.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    executor-config-regression = import ./executor-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    homelab-ingress-regression = import ./homelab-ingress-regression.nix {
      config = self.nixosConfigurations.kim.config;
      fleetPackages = inputs.fleet.packages;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    homelab-inventory-regression = import ./homelab-inventory-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    immich-config-regression = import ./immich-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    media-stack-regression = import ./media-stack-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = self.nixosConfigurations.kim.pkgs;
    };
    media-companions-regression = import ./media-companions-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = self.nixosConfigurations.kim.pkgs;
    };
    tailscale-serve-regression = import ./tailscale-serve-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    homelab-backup-regression = import ./homelab-backup-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    paperless-config-regression = import ./paperless-config-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    homepage-regression = import ./homepage-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    nextcloud-apps-regression = import ./nextcloud-apps-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    template-regression = import ./template-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    monitoring-regression = import ./monitoring-regression.nix {
      config = self.nixosConfigurations.kim.config;
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    };
    fleet-rust-regression = import ./fleet-rust-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      fleetSrc = inputs.fleet;
      homeManager = inputs.home-manager;
    };
    fleet-installed-regression = import ./fleet-installed-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      fleetPackages = inputs.fleet.packages;
      kim = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
      joyce = self.darwinConfigurations.joyce.config.home-manager.users.max-vev;
    };
    morning-report-regression = import ./morning-report-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      kim = self.nixosConfigurations.kim.config.home-manager.users.maxpw;
      cuno = self.nixosConfigurations.cuno.config.home-manager.users.maxpw;
    };
    fleet-trust-regression = import ./fleet-trust-regression.nix {
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
    herdr-core-package = self.packages.aarch64-darwin.herdr-core;
    herdr-config-regression = import ./herdr-config-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      core = self.darwinConfigurations.joyce.pkgs.herdr-core;
      package = inputs.herdr-jj.packages.aarch64-darwin.default;
      home = self.darwinConfigurations.joyce.config.home-manager.users.max-vev;
      files = self.darwinConfigurations.joyce.config.hjem.users.max-vev.files;
    };
    opencode-config-regression = import ./opencode-config-regression.nix {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      package = self.darwinConfigurations.joyce.pkgs.opencode;
      plannotatorVersion = self.darwinConfigurations.joyce.pkgs.plannotator.version;
      home = self.darwinConfigurations.joyce.config.home-manager.users.max-vev;
    };
    git-merge-regression = import ./git-merge-regression.nix {
      inherit lib;
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      home = self.darwinConfigurations.joyce.config.home-manager.users.max-vev;
    };
    jujutsu-workflow-regression = import ./jujutsu-workflow-regression.nix {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      home = self.darwinConfigurations.joyce.config.home-manager.users.max-vev;
      stackPackage = self.packages.aarch64-darwin.jj-stack;
    };
    t3code-package = import ./t3code-package-check.nix {
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
      package = self.packages.aarch64-darwin.t3code;
    };
    eval-joyce = self.darwinConfigurations.joyce.system;
    nvim-candidate = (nvim "aarch64-darwin").nvim-candidate-check;
    nvim-stable = (nvim "aarch64-darwin").nvim-stable-check;
    hjem-lifecycle-regression = import ./hjem-lifecycle-regression.nix {
      inherit (inputs) hjem;
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    };
    pre-commit-check = mkPreCommitCheck "aarch64-darwin";
  };
}
