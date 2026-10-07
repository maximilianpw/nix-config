#!/usr/bin/env bash
# Refresh the Neovim plugin pins in users/maxpw/neovim/plugin-pins.json; this
# replaces lazy.nvim's `:Lazy update`. Native plugins are not pinned here:
# they come from the nixpkgs-unstable input that Nixvim follows.
#
# Usage:
#   scripts/nvim-plugin-pins.sh                 list pins
#   scripts/nvim-plugin-pins.sh NAME [REV]      pin NAME to REV (default: upstream HEAD)
#   scripts/nvim-plugin-pins.sh --all           move every pin to upstream HEAD
#
# Then run: nix build .#checks.$(nix eval --impure --raw --expr builtins.currentSystem).nvim-candidate
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pins="${NVIM_PLUGIN_PINS:-$repo_root/users/maxpw/neovim/plugin-pins.json}"

for tool in jq nix; do
  command -v "$tool" >/dev/null || {
    echo "$tool is required; run inside 'nix develop'" >&2
    exit 1
  }
done

update() {
  local name="$1" rev="${2:-}" owner repo prefetched new_rev hash tmp
  owner="$(jq -er --arg n "$name" '.[$n].owner' "$pins")" || {
    echo "unknown plugin: $name" >&2
    return 1
  }
  repo="$(jq -r --arg n "$name" '.[$n].repo' "$pins")"
  prefetched="$(nix flake prefetch --json "github:$owner/$repo${rev:+/$rev}")"
  new_rev="$(jq -r '.locked.rev' <<<"$prefetched")"
  hash="$(jq -r '.hash' <<<"$prefetched")"
  tmp="$(mktemp "$pins.XXXXXX")"
  jq --arg n "$name" --arg rev "$new_rev" --arg hash "$hash" \
    '.[$n].rev = $rev | .[$n].hash = $hash' "$pins" >"$tmp"
  mv "$tmp" "$pins"
  printf '%-28s %s\n' "$name" "$new_rev"
}

case "${1:-}" in
  "")
    jq -r 'to_entries[] | "\(.key)\t\(.value.owner)/\(.value.repo)\t\(.value.rev[0:12])"' "$pins" | column -t -s $'\t'
    ;;
  --all)
    jq -r 'keys[]' "$pins" | while read -r name; do update "$name"; done
    ;;
  -h | --help)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    ;;
  *)
    update "$1" "${2:-}"
    ;;
esac
