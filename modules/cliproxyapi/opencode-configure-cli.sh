#!/usr/bin/env bash
# Apply Nix-owned CLI preferences without taking ownership of OpenCode's
# writable cli.json or deleting plugins installed by Herdr and other clients.
set -euo pipefail

if [[ $# != 2 ]]; then
  echo "OpenCode CLI configuration: expected DEFAULTS_JSON TARGET_JSON" >&2
  exit 1
fi

defaults=$1
target=$2
if [[ -L $target || ( -e $target && ! -f $target ) ]]; then
  echo "OpenCode CLI configuration: refusing to replace a symlink or non-file: $target" >&2
  exit 1
fi

# Fail closed on malformed/JSONC input rather than discarding local settings.
# OpenCode's own writer and our declarative defaults produce strict JSON.
for input in "$defaults" "$target"; do
  if [[ $input == "$target" && ! -e $target ]]; then
    continue
  fi
  if ! jq -s -e 'length == 1 and (.[0] | type == "object" and ((.plugins // []) | type == "array"))' "$input" >/dev/null; then
    echo "OpenCode CLI configuration: expected a JSON object with an optional plugins array: $input" >&2
    exit 1
  fi
done

umask 077
mkdir -p -- "$(dirname -- "$target")"
temp=$(mktemp "${target}.nix-XXXXXX")
trap 'rm -f -- "$temp"' EXIT

# Defaults own only their declared keys. Preserve all other preferences and
# plugin directives, in order; later local disable directives still win.
current=$target
if [[ ! -e $target ]]; then
  current=/dev/null
fi
jq -s '
  .[0] as $defaults | (.[1] // {}) as $current
  | ($current * $defaults)
  | .plugins = reduce (($defaults.plugins // []) + ($current.plugins // []))[] as $plugin
      ([]; if index($plugin) == null then . + [$plugin] else . end)
' "$defaults" "$current" > "$temp"

# Avoid replacing the file (and triggering watchers) on repeated activation.
if [[ -f $target ]] && cmp -s -- "$target" "$temp"; then
  exit 0
fi
mv -- "$temp" "$target"
