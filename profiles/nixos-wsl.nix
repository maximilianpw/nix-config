# NixOS inside WSL (cuno): a development node without homelab services or a
# login password; secrets decrypt with the admin age key.
_: {
  imports = [./nixos-base.nix];

  custom.sops.keySource = "user";
}
