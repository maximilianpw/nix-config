#!/usr/bin/env bash
# This ensures that the script exits if any command fails and handles errors in pipelines more predictably.
# A rebuild script that commits on a successful build
set -eo pipefail

# cd to your config dir
pushd ~/Nix-Config >/dev/null

# Autoformat your nix files
alejandra . >/dev/null 

echo "Showing changes in Nix files..."
# Shows your changes
git diff -U0 *.nix || true # Continue even if there's nothing to show

echo "NixOS Rebuilding..."
# if ! sudo nixos-rebuild switch --flake "./#$1" >nixos-switch.log 2>&1; then
if ! sudo nixos-rebuild switch --flake "./#$1" 2>&1; then
    echo "Rebuild failed, showing errors:"
    grep --color=always -E "error|warning" nixos-switch.log || true # Show errors if any
    popd >/dev/null
    exit 1
fi

echo "Rebuild successful."

# Get current generation metadata
current=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | grep current | awk '{print $2 " " $3 " " $4}')

# Commit all changes with the generation metadata
git add .
git commit -m "NixOS configuration updated: $current" || echo "No changes to commit."

# Back to where you were
popd >/dev/null
