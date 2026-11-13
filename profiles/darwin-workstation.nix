# Apple Silicon workstation (joyce): Homebrew-managed GUI apps, Determinate
# Nix, CLIProxyAPI as a client of Kim's public endpoint.
_: {
  imports = [
    ../modules/cliproxyapi/darwin.nix
    ../modules/darwin/homebrew.nix
    ../modules/darwin/macos-defaults.nix
    ../modules/fleet/system.nix
    ../modules/hjem/system.nix
    ../modules/hjem/darwin.nix
    ../modules/rex/darwin.nix
    ../modules/shells/system.nix
    ../modules/sops/darwin.nix
    ../modules/t3code/darwin.nix
    ../modules/user-account/darwin.nix
  ];

  home-manager.sharedModules = [
    ../modules/himalaya/home.nix
    ../modules/home/darwin-apps.nix
    ../modules/home/fonts.nix
    ../modules/home/syncthing.nix
    ../modules/home/vicinae.nix
    ../modules/rex/home.nix
  ];
}
