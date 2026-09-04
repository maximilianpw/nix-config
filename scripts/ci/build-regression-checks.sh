#!/usr/bin/env bash

set -euo pipefail

# The flake owns registration. Do not include eval-* host builds or the
# separately scheduled lint check, and do not hide evaluation failures in a
# process substitution feeding the read loop.
names=$(nix eval --raw .#checks.x86_64-linux --apply \
  'checks: builtins.concatStringsSep "\n" (builtins.filter (name: builtins.match ".*-regression" name != null) (builtins.attrNames checks))')
if [[ -z $names ]]; then
  echo "No x86_64-linux regression checks are registered" >&2
  exit 1
fi

checks=()
while IFS= read -r name; do
  checks+=(".#checks.x86_64-linux.$name")
done <<< "$names"

nix build --no-link "${checks[@]}"
