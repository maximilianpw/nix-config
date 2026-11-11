#!/usr/bin/env nix-shell
#!nix-shell -i bash -p curl jq nix python3
# shellcheck shell=bash

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
package_file="$repo_root/packages/cua-driver.nix"
current_version=$(sed -nE 's/^  version = "([0-9]+\.[0-9]+\.[0-9]+)";/\1/p' "$package_file")
tags=()

for page in $(seq 1 10); do
  releases=$(curl --fail --silent --show-error \
    "https://api.github.com/repos/trycua/cua/releases?per_page=100&page=$page")
  while IFS= read -r tag; do
    tags+=("$tag")
  done < <(jq -r '.[] | select(.draft == false) | .tag_name | select(test("^cua-driver-rs-v[0-9]+\\.[0-9]+\\.[0-9]+$"))' <<<"$releases")

  if (($(jq 'length' <<<"$releases") < 100)); then
    break
  fi
done

latest_version=$(printf '%s\n' "${tags[@]}" | sed 's/^cua-driver-rs-v//' | sort -V | tail -n 1)
if [[ -z "$latest_version" ]]; then
  echo "No stable cua-driver-rs release found" >&2
  exit 1
fi
if [[ "$latest_version" == "$current_version" ]]; then
  echo "cua-driver is already at $current_version"
  exit 0
fi

prefetch_hash() {
  local artifact=$1
  local url="https://github.com/trycua/cua/releases/download/cua-driver-rs-v${latest_version}/cua-driver-rs-${latest_version}-${artifact}.tar.gz"
  nix store prefetch-file --json "$url" | jq -r '.hash'
}

darwin_hash=$(prefetch_hash darwin-universal)
linux_arm64_hash=$(prefetch_hash linux-arm64-binary)
linux_x86_64_hash=$(prefetch_hash linux-x86_64-binary)

python3 - "$package_file" "$latest_version" "$darwin_hash" "$linux_arm64_hash" "$linux_x86_64_hash" <<'PY'
import re
import sys
from pathlib import Path

package_file = Path(sys.argv[1])
version, darwin_hash, linux_arm64_hash, linux_x86_64_hash = sys.argv[2:]
text = package_file.read_text()
text, version_changes = re.subn(
    r'(?m)^  version = "[0-9]+\.[0-9]+\.[0-9]+";$',
    f'  version = "{version}";',
    text,
)
if version_changes != 1:
    raise SystemExit(f"expected one version field, changed {version_changes}")

replacements = {
    "aarch64-darwin": darwin_hash,
    "x86_64-darwin": darwin_hash,
    "aarch64-linux": linux_arm64_hash,
    "x86_64-linux": linux_x86_64_hash,
}
for system, hash_value in replacements.items():
    pattern = rf'({re.escape(system)} = \{{\n      name = "[^"]+";\n      hash = ")[^"]+(";)'
    text, changes = re.subn(pattern, rf'\g<1>{hash_value}\2', text)
    if changes != 1:
        raise SystemExit(f"expected one hash field for {system}, changed {changes}")

package_file.write_text(text)
PY

echo "Updated cua-driver from $current_version to $latest_version"
