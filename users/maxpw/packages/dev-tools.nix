{pkgs, ...}: {
  home.packages = [
    # Programming languages & runtimes
    pkgs.nodejs_24
    pkgs.python3
    pkgs.go
    pkgs.rustup
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
