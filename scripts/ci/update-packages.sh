#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
list_file="$script_dir/update-packages-list.txt"
mode=ci

if (($# > 1)); then
  echo "usage: $0 [--local|--print-defaults]" >&2
  exit 2
fi

case "${1:-}" in
  "") ;;
  --local) mode=local ;;
  --print-defaults)
    cat "$list_file"
    exit 0
    ;;
  *)
    echo "usage: $0 [--local|--print-defaults]" >&2
    exit 2
    ;;
esac

packages=()
if [[ -n ${PACKAGES:-} ]]; then
  read -r -a packages <<<"$PACKAGES"
else
  while IFS= read -r package || [[ -n $package ]]; do
    [[ -n $package ]] && packages+=("$package")
  done <"$list_file"
fi

cd "$script_dir/../.."

update_package() {
  local package=$1
  case $package in
    obsidian|herdr-core|plex)
      python3 scripts/dev/update-source-pins.py "$package"
      ;;
    cua-driver)
      bash packages/scripts/update-cua-driver.sh
      ;;
    cloudflared)
      # Go dependency hashing runs on the current host; never edit nixpkgs in the store.
      nix run .#nix-update -- --flake --override-filename flake.nix cloudflared
      ;;
    *)
      # Fetch-only Linux packages can be evaluated from Darwin without building
      # their executables. Select the output explicitly instead of skipping them.
      nix run .#nix-update -- --flake --system x86_64-linux --use-update-script "$package"
      ;;
  esac
}

failed=()

for package in "${packages[@]}"; do
  if [[ $mode == ci ]]; then
    echo "::group::update $package"
  else
    echo ">> update $package"
  fi

  if update_package "$package"; then
    echo "ok: $package"
  else
    echo "failed: $package"
    failed+=("$package")
  fi

  if [[ $mode == ci ]]; then
    echo "::endgroup::"
  fi
done

if ((${#failed[@]} > 0)); then
  echo "Package updates incomplete: ${failed[*]}. Review partial changes and retry the failed packages." >&2
  if [[ $mode == ci ]]; then
    # CI deliberately opens a partial-update PR with this warning in its body.
    echo "failed_packages=${failed[*]}" >>"$GITHUB_OUTPUT"
  else
    exit 1
  fi
fi
