#!/usr/bin/env bash

: "${T3CODE_SYSTEM_USER:?T3CODE_SYSTEM_USER must be set}"
: "${T3CODE_CASK_TOKEN:?T3CODE_CASK_TOKEN must be set}"
: "${T3CODE_RELEASE_VERSION:?T3CODE_RELEASE_VERSION must be set}"
: "${T3CODE_TAP_NAME:?T3CODE_TAP_NAME must be set}"

if [ -x /opt/homebrew/bin/brew ]; then
  run_t3code_brew() {
    sudo \
      --user="$T3CODE_SYSTEM_USER" \
      --set-home \
      -- /opt/homebrew/bin/brew "$@"
  }

  # Homebrew Bundle's `trusted: true` permits installation but does not keep a
  # changing file:// tap trusted for later CLI calls. Trust the current tap
  # before inspecting or pinning its cask.
  run_t3code_brew trust --tap "$T3CODE_TAP_NAME" >/dev/null

  installed_t3code="$(
    run_t3code_brew list --cask --versions "$T3CODE_CASK_TOKEN" \
      2>/dev/null || true
  )"
  installed_t3code_version="${installed_t3code#* }"
  installed_t3code_app_version="$(
    /usr/libexec/PlistBuddy \
      -c "Print :CFBundleShortVersionString" \
      "/Applications/T3 Code (Nightly).app/Contents/Info.plist" \
      2>/dev/null || true
  )"

  if [ "$installed_t3code_version" != "$T3CODE_RELEASE_VERSION" ] ||
    [ "$installed_t3code_app_version" != "$T3CODE_RELEASE_VERSION" ]; then
    echo "error: T3 Code $T3CODE_RELEASE_VERSION was not installed from $T3CODE_TAP_NAME" >&2
    exit 1
  fi

  if ! run_t3code_brew list --cask --pinned |
    /usr/bin/grep -Fxq "$T3CODE_CASK_TOKEN"; then
    run_t3code_brew pin --cask "$T3CODE_CASK_TOKEN"
  fi
fi
