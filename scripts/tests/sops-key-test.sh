#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/sops-key.sh
source "$SCRIPT_DIR/lib/sops-key.sh"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
key="$tmpdir/key.txt"
printf '%s\n' 'test identity' >"$key"
chmod 600 "$key"
metadata=$(sops_key_metadata "$key")
IFS=: read -r uid gid _mode <<<"$metadata"
validate_sops_key "$key" "$uid" "$gid"

chmod 644 "$key"
if validate_sops_key "$key" "$uid" "$gid"; then
    echo "FAIL: permissive key mode was accepted" >&2
    exit 1
fi

rm -f "$key"
mkdir "$key"
if validate_sops_key "$key" "$uid" "$gid"; then
    echo "FAIL: directory was accepted as a key" >&2
    exit 1
fi

rmdir "$key"
printf '%s\n' 'test identity' >"$tmpdir/target"
chmod 600 "$tmpdir/target"
ln -s "$tmpdir/target" "$key"
if validate_sops_key "$key" "$uid" "$gid"; then
    echo "FAIL: symlink was accepted as a key" >&2
    exit 1
fi

echo "sops key tests passed"
