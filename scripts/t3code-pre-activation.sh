#!/usr/bin/env bash
set -euo pipefail

: "${T3CODE_SYSTEM_USER:?T3CODE_SYSTEM_USER must be set}"
: "${T3CODE_BREW_BIN:=/opt/homebrew/bin/brew}"

if [[ -x $T3CODE_BREW_BIN ]]; then
  # Query all installed tokens; no private-tap trust or cask evaluation needed.
  # A failed query must block activation, not be mistaken for an empty install.
  if ! installed=$(sudo --user="$T3CODE_SYSTEM_USER" --set-home -- \
    "$T3CODE_BREW_BIN" list --cask -1); then
    echo "T3 Code migration: cannot inspect installed casks; refusing Homebrew cleanup." >&2
    exit 1
  fi
  while IFS= read -r cask; do
    case "${cask##*/}" in
      maxpw-t3-code-nightly|t3-code|t3-code@nightly)
        echo "T3 Code migration: $cask is still installed through Homebrew." >&2
        echo "Verify the Nix app first, then unpin and uninstall this cask WITHOUT --zap." >&2
        echo "See docs/t3code.md. Activation stopped to protect T3 userdata." >&2
        exit 1
        ;;
    esac
  done <<< "$installed"
fi
