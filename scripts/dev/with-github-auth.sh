#!/usr/bin/env bash
# Run an update command with temporary Nix GitHub authentication from gh.
# Effective nix.conf/NIX_CONFIG tokens take precedence; never persist credentials.
set +x
set -euo pipefail

if (($# == 0)); then
  echo "usage: $0 COMMAND [ARG ...]" >&2
  exit 2
fi

# Inspect effective settings, including tokens configured outside NIX_CONFIG.
# On inspection failure, leave authentication untouched rather than overriding it.
if ! tokens=$(nix config show --json 2>/dev/null | jq -er '."access-tokens".value | objects'); then
  echo "GitHub update authentication: cannot inspect Nix settings; leaving authentication unchanged." >&2
elif [[ $(jq -r 'has("github.com")' <<<"$tokens") != true ]]; then
  if command -v gh >/dev/null 2>&1 && token=$(gh auth token --hostname github.com 2>/dev/null) && [[ -n $token ]]; then
    # extra-access-tokens merges with existing hosts instead of replacing them.
    export NIX_CONFIG="${NIX_CONFIG:+$NIX_CONFIG$'\n'}extra-access-tokens = github.com=$token"
    unset token
  else
    echo "GitHub update authentication: gh is unavailable or not authenticated; continuing without a GitHub token (API rate limits may apply). Run 'gh auth login' to authenticate." >&2
  fi
fi
unset tokens
exec "$@"
