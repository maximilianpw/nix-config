#!/usr/bin/env bash
set -euo pipefail

# Read the lock directly: discovering names must not fetch the private input.
# Empty/whitespace-only FLAKE_INPUTS means every public root input.
available=$(jq -er '.nodes[.root].inputs | keys | map(select(. != "superlocal")) | if length == 0 then error("no public inputs") else .[] end' flake.lock)
requested=$(printf '%s' "${FLAKE_INPUTS:-}" | tr '[:space:]' '\n')
inputs=()
while IFS= read -r input; do
  [[ -n $input ]] || continue
  if [[ ! $input =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || ! grep -Fxq -- "$input" <<< "$available"; then
    printf 'Invalid public flake input: %s\n' "$input" >&2
    exit 1
  fi
  inputs+=("$input")
done <<< "$requested"

# Emit only after all names validate, so callers never act on partial output.
if [[ ${#inputs[@]} == 0 ]]; then
  printf '%s\n' "$available"
else
  printf '%s\n' "${inputs[@]}" | LC_ALL=C sort -u
fi
