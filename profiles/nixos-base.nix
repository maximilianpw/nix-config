# Shared by every NixOS role profile; not a role itself.
_: {
  imports = [
    ../modules/cliproxyapi/nixos.nix
    ../modules/fleet/nixos.nix
    ../modules/fleet/system.nix
    ../modules/hjem/system.nix
    ../modules/nixos/linux-base.nix
    ../modules/nixos/nix-settings.nix
    ../modules/shells/system.nix
    ../modules/sops/nixos.nix
    ../modules/user-account/nixos.nix
  ];
}
