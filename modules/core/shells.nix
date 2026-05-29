# System-level shell registration (NixOS + nix-darwin).
# Nushell is the primary interactive shell; fish/bash/zsh are kept for
# compatibility. Per-shell user config lives in users/*/modules/shells.nix.
{pkgs, ...}: {
  programs.fish.enable = true;
  environment.shells = [
    pkgs.nushell
    pkgs.fish
    pkgs.bashInteractive
    pkgs.zsh
  ];
}
