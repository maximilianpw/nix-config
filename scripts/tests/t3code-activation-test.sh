#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
pre_activation="$repo_root/scripts/t3code-pre-activation.sh"
post_activation="$repo_root/scripts/t3code-post-activation.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
# sudo runs the requested command; git only answers the tap remote lookup.
cat > "$tmp/bin/sudo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
while [[ $1 != -- ]]; do shift; done
shift
if [[ $1 == /usr/bin/git ]]; then
  printf '%s\n' "$FAKE_TAP_URL"
  exit 0
fi
exec "$@"
EOF
cat > "$tmp/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$CASE_DIR/log"
has() { grep -Fxq "$1" "$CASE_DIR/$2" 2>/dev/null; }
drop() { grep -Fxv "$1" "$CASE_DIR/$2" > "$CASE_DIR/$2.new" || true; mv "$CASE_DIR/$2.new" "$CASE_DIR/$2"; }
case "$*" in
  tap) cat "$CASE_DIR/taps" ;;
  "trust --tap "*) ;;
  "--repo "*) printf '/fake/tap\n' ;;
  "untap --force "*) drop "${!#}" taps ;;
  "list --cask --pinned") cat "$CASE_DIR/pinned" ;;
  "list --cask --versions "*)
    has "${!#}" casks && printf '%s %s\n' "${!#}" "$FAKE_CASK_VERSION"
    ;;
  "list --cask "*) has "${!#}" casks ;;
  "unpin --cask "*) drop "${!#}" pinned ;;
  "uninstall --cask "*) drop "${!#}" casks ;;
  "pin --cask "*) printf '%s\n' "${!#}" >> "$CASE_DIR/pinned" ;;
  *) echo "unexpected brew call: $*" >&2; exit 2 ;;
esac
EOF
cat > "$tmp/plistbuddy" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$FAKE_APP_VERSION"
EOF
chmod +x "$tmp/bin/sudo" "$tmp/brew" "$tmp/plistbuddy"

export PATH="$tmp/bin:$PATH"
export T3CODE_SYSTEM_USER=tester
export T3CODE_CASK_TOKEN=maxpw-t3-code-nightly
export T3CODE_RELEASE_VERSION=1.2.3
export T3CODE_TAP_NAME=maxpw/t3code-nightly
export T3CODE_TAP_URL=file:///nix/store/new-tap
export T3CODE_BREW_BIN=$tmp/brew
export T3CODE_PLISTBUDDY_BIN=$tmp/plistbuddy
# The activation scripts default to macOS /usr/bin/grep; tests run on Linux too.
export T3CODE_GREP_BIN
T3CODE_GREP_BIN=$(command -v grep)

# Arguments: case name, then installed casks. The tap is present, current, and
# unpinned unless a case overrides the fixture.
new_case() {
  CASE_DIR="$tmp/$1"
  export CASE_DIR
  shift
  mkdir -p "$CASE_DIR"
  : > "$CASE_DIR/log"
  : > "$CASE_DIR/pinned"
  printf '%s\n' "$T3CODE_TAP_NAME" > "$CASE_DIR/taps"
  printf '%s\n' "$T3CODE_CASK_TOKEN" "$@" > "$CASE_DIR/casks"
  export FAKE_CASK_VERSION=$T3CODE_RELEASE_VERSION
  export FAKE_APP_VERSION=$T3CODE_RELEASE_VERSION
  export FAKE_TAP_URL=$T3CODE_TAP_URL
}

called() { grep -Fxq "$1" "$CASE_DIR/log"; }
line_of() { grep -Fxn "$1" "$CASE_DIR/log" | head -n 1 | cut -d: -f1; }
trusted_before_inspection() {
  local trust inspect
  trust=$(line_of "trust --tap $T3CODE_TAP_NAME")
  inspect=$(line_of "list --cask --versions $T3CODE_CASK_TOKEN")
  [[ -n $trust && -n $inspect && $trust -lt $inspect ]]
}

# Pre-activation: a current install keeps its tap and is trusted before inspection.
new_case pre-current
bash "$pre_activation"
trusted_before_inspection
! called "untap --force $T3CODE_TAP_NAME"

# A tap cloned from an older store path is replaced.
new_case pre-stale-url
export FAKE_TAP_URL=file:///nix/store/old-tap
bash "$pre_activation"
called "untap --force $T3CODE_TAP_NAME"

# An outdated cask is uninstalled and its tap dropped so Bundle reinstalls both.
new_case pre-outdated
export FAKE_APP_VERSION=1.0.0
bash "$pre_activation"
called "uninstall --cask $T3CODE_CASK_TOKEN"
called "untap --force $T3CODE_TAP_NAME"

# Official casks are migrated without zapping shared state.
new_case pre-migrate t3-code
bash "$pre_activation"
called "uninstall --cask t3-code"
! grep -q zap "$CASE_DIR/log"

# Post-activation: trust, verify, and pin the installed cask.
new_case post-current
bash "$post_activation"
trusted_before_inspection
called "pin --cask $T3CODE_CASK_TOKEN"

# An already pinned cask is left alone.
new_case post-pinned
printf '%s\n' "$T3CODE_CASK_TOKEN" > "$CASE_DIR/pinned"
bash "$post_activation"
! called "pin --cask $T3CODE_CASK_TOKEN"

# A version mismatch after Bundle fails activation.
new_case post-mismatch
export FAKE_APP_VERSION=1.0.0
if bash "$post_activation" 2> "$CASE_DIR/err"; then
  echo "post-activation accepted a mismatched T3 Code version" >&2
  exit 1
fi
grep -Fq "was not installed from $T3CODE_TAP_NAME" "$CASE_DIR/err"

# Without Homebrew (first activation) both scripts are no-ops.
new_case no-brew
T3CODE_BREW_BIN=$tmp/missing-brew bash "$pre_activation"
T3CODE_BREW_BIN=$tmp/missing-brew bash "$post_activation"
[[ ! -s $CASE_DIR/log ]]

echo "T3 Code activation tests passed"
