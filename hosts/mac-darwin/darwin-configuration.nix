{
  config,
  pkgs,
  lib,
  ...
}: {
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
