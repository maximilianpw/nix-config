#!/usr/bin/env bash

set -euo pipefail

selected=${PACKAGES:-}
if [[ -z "$selected" ]]; then
  selected=$(nix eval --raw .#lib.packageUpdates)
fi
read -r -a packages <<<"$selected"
if ((${#packages[@]} == 0)); then
  echo "No updateable packages registered or selected" >&2
  exit 1
fi
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
