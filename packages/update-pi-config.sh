#!/usr/bin/env bash
# Records pi-config's dependency hashes after the pi-config input moves. Both
# platforms build here: Bun installs another platform's packages on request.
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
package_file=$repo_root/packages/pi-config.nix

for platform in linux-x64 darwin-arm64; do
  expr="((builtins.getFlake \"git+file://$repo_root\").packages.\${builtins.currentSystem}.pi-config.override {bunOs = \"${platform%-*}\"; bunCpu = \"${platform#*-}\";}).nodeModules"
  if output=$(nix build --no-link --impure --expr "$expr" 2>&1); then
    echo "pi-config $platform dependencies are current"
    continue
  fi
  hash=$(sed -n 's/^ *got: *//p' <<<"$output")
  if [[ -z $hash ]]; then
    printf '%s\n' "$output" >&2
    exit 1
  fi
  sed -i.orig -E "s|^(    $platform = )\"[^\"]*\";|\\1\"$hash\";|" "$package_file"
  rm "$package_file.orig"
  echo "pi-config $platform dependencies now $hash"
done
