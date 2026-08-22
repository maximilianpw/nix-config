#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
post_activation="$script_dir/t3code-post-activation.sh"

trust_line="$({ grep -nF 'run_t3code_brew trust --tap "$T3CODE_TAP_NAME" >/dev/null' "$post_activation" || true; } | cut -d: -f1)"
version_check_line="$({ grep -nF 'run_t3code_brew list --cask --versions "$T3CODE_CASK_TOKEN"' "$post_activation" || true; } | cut -d: -f1)"

if [[ -z $trust_line ]]; then
  echo "T3 Code post-activation must persist trust for the generated tap" >&2
  exit 1
fi

if [[ -z $version_check_line || $trust_line -ge $version_check_line ]]; then
  echo "T3 Code tap must be trusted before inspecting the installed cask" >&2
  exit 1
fi

echo "T3 Code post-activation tests passed"
