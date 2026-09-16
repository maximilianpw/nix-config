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

failed=()

for package in "${packages[@]}"; do
  if [[ $mode == ci ]]; then
    echo "::group::nix-update $package"
  else
    echo ">> nix-update $package"
  fi

  if nix run .#nix-update -- --flake --use-update-script "$package"; then
    echo "ok: $package"
  elif [[ $mode == local ]]; then
    echo "(skipped: $package)"
  else
    echo "failed: $package"
    failed+=("$package")
  fi

  if [[ $mode == ci ]]; then
    echo "::endgroup::"
  fi
done

if [[ $mode == ci ]] && ((${#failed[@]} > 0)); then
  echo "failed_packages=${failed[*]}" >>"$GITHUB_OUTPUT"
fi
