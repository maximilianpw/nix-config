#!/usr/bin/env bash
# Install globally-scoped agent skills declaratively.
#
# Source of truth for which skills should exist on every machine. Run via
# `make skills` (or this script directly) on a new system, or re-run to pick
# up newly-added entries. Existing skills are left alone by the CLI.
#
# Requires the `skills` CLI, which is provided by packages/skills.nix and
# installed globally via dev-tools.nix. Updates for already-installed skills
# come from `skills update`, not this script.

set -euo pipefail

SKILLS=(
  "mattpocock/skills@tdd"
  "mattpocock/skills@grill-me"
  "mattpocock/skills@write-a-prd"
  "mattpocock/skills@improve-codebase-architecture"
  "mattpocock/skills@prd-to-issues"
  "vercel-labs/skills@find-skills"
)

if ! command -v skills >/dev/null 2>&1; then
  echo "error: skills CLI not found on PATH — run 'make rebuild' first so home-manager installs it." >&2
  exit 1
fi

for skill in "${SKILLS[@]}"; do
  echo ">> skills add ${skill}"
  skills add "${skill}" -g -y
done

echo
echo "Done. Installed skills:"
skills list -g
