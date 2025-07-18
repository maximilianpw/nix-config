{
  inputs,
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./homebrew.nix
  ];

  system = {
    primaryUser = "max-vev";
  };

  users.users.max-vev.home = "/Users/max-vev/";
  home-manager.users.max-vev = {
    home.username = "max-vev";
    home.homeDirectory = "/Users/max-vev/";
    home.stateVersion = "25.05";

    home.packages = with pkgs; [
      ngrok
    ];
  };

  environment.systemPackages = with pkgs; [
    checkstyle
    mongosh
    nushell
    rustc
    rustup
    sops
    vale
    jujutsu
    go
    git
    gh
    lazygit
    stow
    tree
    deno
    fzf
    eslint
    btop
    terraform
    fish
    cmatrix
    zoxide
    lua
    neofetch
    openjdk
    awscli2
    neovim
    ripgrep
    asdf
    alejandra
    zsh
    go
    nodejs
    python3
    zsh
    zoxide
    starship
  ];

  nix.settings.experimental-features = ["nix-command" "flakes"];

  nixpkgs.config.allowUnfree = true;

  # Optional: Set system revision if available
  system.configurationRevision = lib.mkIf (config ? _module.args.self) (
    config._module.args.self.rev or config._module.args.self.dirtyRev or null
  );

  system.stateVersion = 6;

  nixpkgs.hostPlatform = "aarch64-darwin";
}
