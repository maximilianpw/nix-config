#!/usr/bin/env bash
# Hjem linker lifecycle against a disposable home, using the same
# `hjem internal activate` call as Hjem's nix-darwin launch agent and NixOS
# activation service. Run by the `hjem-lifecycle-regression` flake check.
#
# Asserts only the properties this repository relies on: links and copies are
# created and removed, nothing a user or another owner wrote is deleted, the
# two-stage handoff works, and older manifests roll back. Known upstream hazards
# (single-use backup slot, partial failures, warn-only validation) are recorded
# in docs/nixvim-hjem-ledger.md rather than pinned here, so an upstream fix does
# not fail this check.
set -euo pipefail

: "${HJEM:?HJEM must be set}"

work="$(mktemp -d "${TMPDIR:-/tmp}/hjem-lifecycle.XXXXXX")"
work="$(cd "$work" && pwd -P)"
trap 'rm -rf "$work"' EXIT
home="$work/home"
src="$work/src"
state="$work/state"
mkdir -p "$home" "$src" "$state" "$work/other-owner"
for name in a b c tool; do
  printf '%s\n' "$name" >"$src/$name"
done
printf 'other owner\n' >"$work/other-owner/c"

failures=0
pass() { printf 'ok   %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n' "$1"
  failures=$((failures + 1))
}
expect() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

symlink() { printf '{"type":"symlink","source":"%s","target":"%s"}' "$1" "$2"; }
copy() { printf '{"type":"copy","source":"%s","target":"%s","permissions":"%s"}' "$1" "$2" "$3"; }
manifest() {
  local name="$1" entries
  shift
  entries="$(IFS=,; printf '%s' "$*")"
  printf '{"version":3,"files":[%s]}\n' "$entries" >"$work/$name.json"
}
activate() {
  "$HJEM" internal activate \
    --manifest "$work/$1.json" \
    --state "$state/manifest.json" \
    --actions-file "$state/actions.json" \
    --prefix .backup- >"$work/$1.log" 2>&1
}
links_to() { [[ -L "$1" && "$(readlink "$1")" == "$2" ]]; }
content_is() { [[ -f "$1" && "$(cat "$1")" == "$2" ]]; }

manifest v1 \
  "$(symlink "$src/a" "$home/.config/app/a")" \
  "$(symlink "$src/c" "$home/.config/app/c")" \
  "$(copy "$src/tool" "$home/.local/bin/tool" 755)"
manifest v2 \
  "$(symlink "$src/a" "$home/.config/app/a")" \
  "$(symlink "$src/b" "$home/.config/app/b")" \
  "$(symlink "$src/c" "$home/.config/app/c")"
manifest v3 "$(symlink "$src/a" "$home/.config/app/a")"
manifest v2-blocked \
  "$(symlink "$src/a" "$home/.config/app/a")" \
  "$(symlink "$src/b" "$home/.config/app/b")" \
  "$(symlink "$src/c" "$home/.config/app/c")" \
  "$(symlink "$src/a" "$home/.config/blocked/a")"

echo "--- create, update, executable copy ---"
expect "initial activation succeeds" activate v1
expect "symlink created with parent directories" links_to "$home/.config/app/a" "$src/a"
expect "copied file keeps requested mode" test -x "$home/.local/bin/tool"
expect "copied file is a real file, not a link" test ! -L "$home/.local/bin/tool"

echo "--- unmanaged collision ---"
printf 'user data\n' >"$home/.config/app/b"
expect "activation over an unmanaged file succeeds" activate v2
expect "unmanaged file is kept under the backup prefix" content_is "$home/.config/app/.backup-b" "user data"
expect "managed link replaces it" links_to "$home/.config/app/b" "$src/b"
expect "file dropped from the manifest is removed" test ! -e "$home/.local/bin/tool"

echo "--- conflicting parent path ---"
printf 'not a directory\n' >"$home/.config/blocked"
activate v2-blocked || true
expect "a file where a parent directory is needed is preserved" content_is "$home/.config/blocked" "not a directory"
expect "existing managed links are untouched" links_to "$home/.config/app/c" "$src/c"
rm "$home/.config/blocked"

echo "--- other owners' files are never deleted ---"
rm "$home/.config/app/c"
ln -s "$work/other-owner/c" "$home/.config/app/c"
activate v3 || true
expect "dropping a path another owner now holds keeps their link" links_to "$home/.config/app/c" "$work/other-owner/c"

echo "--- two-stage handoff ---"
rm "$home/.config/app/c"
expect "Hjem releases the path first" activate v3
expect "released path is removed" test ! -e "$home/.config/app/c"
ln -s "$work/other-owner/c" "$home/.config/app/c"
expect "a later activation leaves the new owner's file alone" activate v3
expect "new owner's link intact" links_to "$home/.config/app/c" "$work/other-owner/c"

echo "--- rollback ---"
rm "$home/.config/app/c"
expect "re-applying an earlier manifest succeeds" activate v1
expect "earlier links are restored" links_to "$home/.config/app/c" "$src/c"
expect "earlier copies are restored" test -x "$home/.local/bin/tool"

echo "--- user-edited copies are never deleted ---"
edited="$work/edited"
mkdir -p "$edited/home" "$edited/state"
eactivate() {
  "$HJEM" internal activate --manifest "$edited/$1.json" --state "$edited/state/manifest.json" \
    --actions-file "$edited/state/actions.json" --prefix .backup- >"$edited/$1.log" 2>&1
}
printf '{"version":3,"files":[%s]}\n' "$(copy "$src/a" "$edited/home/copied" 644)" >"$edited/with.json"
printf '{"version":3,"files":[%s]}\n' "$(symlink "$src/a" "$edited/home/a")" >"$edited/without.json"
expect "copy fixture activates" eactivate with
printf 'local edit\n' >>"$edited/home/copied"
eactivate without || true
expect "dropping an edited copy keeps the edit" grep -q "local edit" "$edited/home/copied"

if [[ $failures -ne 0 ]]; then
  echo "$failures Hjem lifecycle expectation(s) changed; review before relying on this pin." >&2
  exit 1
fi
echo "Hjem lifecycle fixture passed."
