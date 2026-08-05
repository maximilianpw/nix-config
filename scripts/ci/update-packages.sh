#!/usr/bin/env bash

set -euo pipefail

read -r -a packages <<<"${PACKAGES:-$DEFAULT_PACKAGES}"
failed=()

for package in "${packages[@]}"; do
  echo "::group::nix-update $package"
  if nix run .#nix-update -- --flake --use-update-script "$package"; then
    echo "ok: $package"
  else
    echo "failed: $package"
    failed+=("$package")
  fi
  echo "::endgroup::"
done

if ((${#failed[@]} > 0)); then
  echo "failed_packages=${failed[*]}" >>"$GITHUB_OUTPUT"
fi
