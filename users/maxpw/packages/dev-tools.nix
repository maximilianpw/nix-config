{pkgs, ...}: {
  home.packages = [
    # Programming languages & runtimes
    pkgs.nodejs_24
    pkgs.pnpm
    pkgs.python3
    pkgs.go
    # Rust: managed via Homebrew on macOS, Nix on NixOS
    pkgs.rustc
    pkgs.cargo
    pkgs.rustfmt
    pkgs.rust-analyzer
    pkgs.deno
    pkgs.lua
    pkgs.dotnet-sdk_9
    pkgs.openjdk

    # Language servers & formatters
    pkgs.netcoredbg
    pkgs.prettierd
    pkgs.eslint
    pkgs.checkstyle
    pkgs.tflint

    # Build tools & dependencies
    pkgs.gcc
    pkgs.gnumake
    pkgs.alejandra

    # Databases & tools
    pkgs.mongosh
    pkgs.mongodb-compass

    # Cloud & infrastructure
    pkgs.terraform
    pkgs.awscli2

    # Dev tools
    pkgs.sops
    pkgs.asdf
  ];
}
