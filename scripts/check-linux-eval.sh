#!/usr/bin/env bash
# Force every x86_64-linux check's assertions from any host. `nix flake check`
# on Darwin skips foreign systems, so homelab and Fleet regressions would
# otherwise never run locally. Build-time script steps still need a Linux
# builder; see `nix build .#checks.x86_64-linux.<name>`.
set -euo pipefail

failed=$(nix eval --raw .#checks.x86_64-linux --apply '
  checks: builtins.concatStringsSep "\n" (builtins.filter
    (name: !(builtins.tryEval (builtins.deepSeq checks.${name}.drvPath true)).success)
    (builtins.attrNames checks))')

if [[ -z $failed ]]; then
  echo "All x86_64-linux checks evaluate"
  exit 0
fi

while IFS= read -r name; do
  echo "FAIL $name" >&2
  nix eval --raw ".#checks.x86_64-linux.$name.drvPath" 2>&1 >/dev/null | grep -E 'error: [^ ]' | tail -n 1 >&2 || true
done <<< "$failed"
exit 1
