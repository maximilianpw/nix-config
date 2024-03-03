#!/usr/bin/env bash
# A rebuild script that commits on a successful build
set -e

# cd to your config dir
pushd ~/Nix-Config/

# Autoformat your nix files
alejandra . &>/dev/null

# Shows your changes
git diff -U0 *.nix

echo "NixOS Rebuilding..."

# Rebuild, output simplified errors, log tracebacks
sudo nixos-rebuild switch --flake ./#$1 &>nixos-switch.log || (cat nixos-switch.log | grep --color error && false)

# Get current generation metadata
current=$(nixos-rebuild list-generations | grep current)

# Commit all changes witih the generation metadata
git commit -am "$current"

# Back to where you were
popd

