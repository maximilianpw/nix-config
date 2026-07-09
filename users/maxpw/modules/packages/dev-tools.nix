{pkgs, ...}: {
  home.packages = [
    # Programming languages & runtimes
    pkgs.nodejs_24
    pkgs.pnpm
    pkgs.bun
    pkgs.python3
    pkgs.go
    # Rust via fenix (stable, project flakes provide full toolchains)
    (pkgs.fenix.stable.withComponents [
      "cargo"
      "clippy"
      "rustc"
      "rustfmt" # conform formats Rust via the rustfmt binary
    ])
    pkgs.deno
    pkgs.lua
    pkgs.zig
    pkgs.openjdk
    pkgs.golangci-lint

    # Shared editor tooling. Keep these on the normal PATH so Neovim, Zed,
    # Jujutsu hooks, and terminal workflows all resolve the same binaries.
    pkgs.biome
    pkgs.black
    pkgs.checkstyle
    pkgs.clang-tools
    pkgs.eslint
    pkgs.gofumpt
    pkgs.gotools # goimports and other Go source tools
    pkgs.oxlint
    pkgs.prettier
    pkgs.prettierd
    pkgs.ruff
    pkgs.shfmt
    pkgs.stylua
    pkgs.taplo

    # Build tools & dependencies
    pkgs.gnumake
    pkgs.alejandra

    # Databases & tools
    pkgs.mongosh

    # Cloud & infrastructure
    pkgs.terraform
    pkgs.awscli2
    pkgs.graphite-cli

    # Dev tools
    pkgs.ast-grep
    pkgs.sops
    pkgs.coderabbit
  ];
}
