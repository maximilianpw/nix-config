{
  description = "NixOS & Nix-Darwin configuration by @maximilianpw";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Nix packaging was added after v0.1.7; keep its Python 3.14 package set.
    jj-stack.url = "github:bos/jj-stack/a520798bd0c870437c8b427f5a15c94e5dac5c11";

    vite-plus = {
      url = "github:ryoppippi/nix-vite-plus";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    fleet = {
      url = "github:maximilianpw/fleet/b7a6dff50dea014c09a9949ee1e160dab57c3ebf";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };

    # Own terminal log viewer; pinned to a release tag so every host gets the
    # same binary without depending on the Homebrew tap.
    loggle = {
      url = "github:maximilianpw/loggle/v0.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Own Linear TUI that opens a Rex session per issue; pinned to a release tag.
    linrex = {
      url = "github:maximilianpw/linrex/v0.3.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Release-pinned Herdr plugin; Bun >= 1.3.14 and JJ >= 0.46 need unstable.
    herdr-jj = {
      url = "github:maximilianpw/herdr-jj/v0.1.1";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Private homelab MCP; pin an upstream release and consume its package.
    homelab-mcp = {
      url = "git+ssh://git@github.com/maximilianpw/homelab-mcp?ref=refs/tags/v0.1.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Own music server; consume its package rather than vendoring its source.
    leerr = {
      url = "github:maximilianpw/leerr";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Prebuilt Rex. Until its first release the package host needs a netrc
    # token on every evaluating machine (BOOTSTRAP.md); CI uses tests/stubs/rex.
    rex = {
      url = "https://pkgs.superlogical.com/rex/nix/preview.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Own Trade Republic tracker; consume its package and NixOS module.
    portfolio-tracker = {
      url = "github:maximilianpw/portfolio-tracker/v0.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

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

    # Neovim configuration framework (users/maxpw/neovim). Its package set
    # follows nixpkgs-unstable, matching the editor Home Manager installs today.
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # Neovim development (0.13-dev) editor for the terminal profile. Its own
    # nixpkgs is kept: following ours can break its Tree-sitter vendor hashes.
    # The nested neovim-src revision is what `nix flake update` advances.
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

    # Manifest-based $HOME linker. Its nix-darwin module adds launch agents
    # even with no users.
    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    git-hooks,
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;
    hosts = import ./lib/inventory.nix {inherit lib;};

    overlays = import ./overlays.nix inputs;

    mkSystem = import ./lib/mksystem.nix {
      inherit overlays nixpkgs inputs;
      hostInventory = hosts;
    };

    nixosHosts = lib.filterAttrs (_: host: !host.darwin) hosts;
    darwinHosts = lib.filterAttrs (_: host: host.darwin) hosts;
    mkPkgs = system:
      import nixpkgs {
        inherit system overlays;
        config.allowUnfree = true;
      };

    # Nixvim editor packages; language tooling comes from the same stable
    # package set Home Manager uses.
    nvim = system:
      import ./users/maxpw/neovim/packages.nix {
        inherit inputs system;
        toolPkgs = mkPkgs system;
      };

    desktopKim = mkSystem "kim" (hosts.kim
      // {
        linuxDesktop = true;
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
    nixosConfigurations = lib.mapAttrs mkSystem nixosHosts;
    darwinConfigurations = lib.mapAttrs mkSystem darwinHosts;

    # Locked reprovisioning tool. The layout itself remains intentionally
    # separate from live mounts and must only be run after a manual disk review.
    apps.x86_64-linux.disko = {
      type = "app";
      program = "${inputs.disko.packages.x86_64-linux.disko}/bin/disko";
    };

    # Eval-only checks catch typos, missing modules, and type errors without building.
    checks = import ./tests {
      inherit desktopKim hosts inputs lib mkPreCommitCheck nixpkgs nvim self;
    };

    # Custom packages exposed as flake outputs so `nix build .#<name>` and
    # `nix-update --flake <name>` can find them. The overlay still injects
    # these into `pkgs.*` for module consumption — this is additive.
    packages = let
      editorPackages = system: {
        inherit (nvim system) nvim nvim-stable nvim-vscode nvim-candidate nvim-vscode-candidate;
        inherit (mkPkgs system) lazygit-nvim-edit;
      };
    in {
      x86_64-linux = let
        pkgs = mkPkgs "x86_64-linux";
      in
        editorPackages "x86_64-linux"
        // {
          inherit (pkgs) cloudflared plannotator;
          inherit (pkgs) helium obsidian skills cliproxyapi cua-driver hunkdiff nix-update tunarr jellyfin jellyfin-web jellyfin-ffmpeg vite-plus t3code herdr-core herdr-jj;
          inherit (inputs.jj-stack.packages.x86_64-linux) jj-stack;
        };
      aarch64-darwin = let
        pkgs = mkPkgs "aarch64-darwin";
      in
        editorPackages "aarch64-darwin"
        // {
          inherit (pkgs) cloudflared plannotator;
          inherit (pkgs) cua-driver skills hunkdiff nix-update obsidian vite-plus t3code herdr-core herdr-jj;
          inherit (inputs.jj-stack.packages.aarch64-darwin) jj-stack;
        };
    };

    formatter = nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux" "aarch64-darwin"] (
      system: nixpkgs.legacyPackages.${system}.alejandra
    );

    devShells = nixpkgs.lib.genAttrs ["aarch64-linux" "x86_64-linux" "aarch64-darwin"] (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        buildInputs = with pkgs;
          [
            actionlint
            alejandra
            bashInteractive
            curl
            deadnix
            git
            gnumake
            gh
            jq
            nodejs
            python3
            rsync
            shellcheck
            statix
          ]
          # On macOS, use the host's Determinate Nix instead of shadowing it.
          ++ lib.optionals stdenv.isLinux [nix];
        shellHook = ''
          # Child terminals need completion/readline support, not stdenv's minimal Bash.
          export SHELL=${pkgs.bashInteractive}/bin/bash
          ${self.checks.${system}.pre-commit-check.shellHook or ""}
          echo "Welcome to the Nix dev shell for ${system}"
        '';
      };
    });
  };
}
