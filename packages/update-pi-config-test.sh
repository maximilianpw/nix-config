#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/repo/packages" "$tmp/bin"
git -C "$tmp/repo" init --quiet
cat >"$tmp/repo/packages/pi-config.nix" <<'EOF'
  hashes = {
    linux-x64 = "sha256-OLDLINUX";
    darwin-arm64 = "sha256-OLDDARWIN";
  };
EOF

# A changed Linux lockfile: its build reports a new hash; Darwin's is current.
cat >"$tmp/bin/nix" <<'EOF'
#!/bin/sh
case "$*" in
  *'bunOs = "linux"'*)
    [ -z "${TEST_NO_HASH:-}" ] || { echo 'error: builder failed'; exit 1; }
    printf 'error: hash mismatch\n         specified: sha256-OLDLINUX\n            got:    sha256-NEWLINUX\n'
    exit 1
    ;;
esac
EOF
chmod +x "$tmp/bin/nix"
export PATH="$tmp/bin:$PATH"

(cd "$tmp/repo" && bash "$here/update-pi-config.sh") >"$tmp/out"
grep -Fxq '    linux-x64 = "sha256-NEWLINUX";' "$tmp/repo/packages/pi-config.nix"
grep -Fxq '    darwin-arm64 = "sha256-OLDDARWIN";' "$tmp/repo/packages/pi-config.nix"
grep -Fq 'darwin-arm64 dependencies are current' "$tmp/out"
[[ ! -e $tmp/repo/packages/pi-config.nix.orig ]]

if (cd "$tmp/repo" && TEST_NO_HASH=1 bash "$here/update-pi-config.sh") >"$tmp/out" 2>"$tmp/err"; then
  echo 'a build failure without a hash unexpectedly passed' >&2
  exit 1
fi
grep -Fq 'builder failed' "$tmp/err"

echo "pi-config updater tests passed"
