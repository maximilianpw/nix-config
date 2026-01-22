{pkgs, ...}: {
  home.packages = [
    # Programming languages & runtimes
    pkgs.nodejs_24
    pkgs.pnpm
    pkgs.bun
    pkgs.python3
    pkgs.go
    # Rust via fenix (nightly toolchain)
    (pkgs.fenix.complete.withComponents [
      "cargo"
      "clippy"
      "rust-src"
      "rustc"
      "rustfmt"
    ])
    pkgs.rust-analyzer-nightly
    pkgs.deno
    pkgs.lua
    pkgs.openjdk
    pkgs.golangci-lint

    # Language servers & formatters
    pkgs.prettierd
    pkgs.eslint
    pkgs.checkstyle

    # Build tools & dependencies
    pkgs.gcc
    pkgs.gnumake
    pkgs.alejandra

    # Databases & tools
    pkgs.mongosh

    # Cloud & infrastructure
    pkgs.terraform
    pkgs.awscli2
    pkgs.graphite-cli

    # Dev tools
    pkgs.sops
    pkgs.asdf
  ];
}
