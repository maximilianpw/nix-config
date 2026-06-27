{
  isDarwin,
  pkgs,
  lib,
  ...
}: {
  home.packages =
    [
      # Programming languages & runtimes
      pkgs.nodejs_24
      pkgs.pnpm
      pkgs.bun
      pkgs.python3
      pkgs.go
      # Rust via fenix (stable, project flakes provide full toolchains)
      (pkgs.fenix.stable.withComponents [
        "cargo"
        "rustc"
        "rustfmt" # conform formats Rust via the rustfmt binary
      ])
      pkgs.deno
      pkgs.lua
      pkgs.zig
      pkgs.openjdk
      pkgs.golangci-lint

      # Language servers & formatters
      # (prettierd is editor-only; it lives in modules/neovim.nix extraPackages)
      pkgs.eslint
      pkgs.biome
      pkgs.oxlint
      pkgs.checkstyle

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
      pkgs.mise
      pkgs.comma
      pkgs.coderabbit
    ]
    ++ lib.optionals (!isDarwin) [
      # AI agents. macOS uses the upstream installer so Desktop and CLI share
      # the same mutable ~/.hermes checkout.
      pkgs.hermes # Hermes Agent CLI (Nous Research)
    ];
}
