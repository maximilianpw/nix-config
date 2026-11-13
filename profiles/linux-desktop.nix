# Hyprland desktop on top of a NixOS role profile; selected by a host's
# `linuxDesktop` capability (parked: kim is headless, flake.nix keeps
# `desktopKim` evaluable).
_: {
  imports = [
    ../modules/hyprland/nixos.nix
    ../modules/linux-desktop/nixos.nix
  ];

  custom.hyprland.enable = true;

  home-manager.sharedModules = [
    ../modules/himalaya/home.nix
    ../modules/home/fonts.nix
    ../modules/home/stylix.nix
    ../modules/home/vicinae.nix
    ../modules/hyprland/home.nix
    ../modules/linux-desktop/home.nix
    ../modules/onepassword/home.nix
  ];
}
