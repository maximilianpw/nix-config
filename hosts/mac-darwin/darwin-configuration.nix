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

  # system.primaryUser = "max-vev";

home-manager.users.max-vev = {
  home.username = "max-vev";
  home.homeDirectory = "/Users/max-vev";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    appcleaner
    arc-browser
    chatgpt
    discord
    google-chrome
    notion-app
    postman
    rectangle
    slack
    termius
    the-unarchiver
    vscode
    jetbrains.idea-ultimate
    jetbrains.webstorm
    mongodb-compass
    ngrok
  ];

  # More home-manager user config here!
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
    angular-cli
    go
    jsonlint
    nodejs 
    python3 
    zsh
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
