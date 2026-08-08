#!/usr/bin/env bash

: "${out:?out must be set by Nix runCommand}"
: "${T3CODE_NIGHTLY_CASK:?T3CODE_NIGHTLY_CASK must be set}"
: "${T3CODE_CASK_TOKEN:?T3CODE_CASK_TOKEN must be set}"
: "${T3CODE_RELEASE_VERSION:?T3CODE_RELEASE_VERSION must be set}"

mkdir -p "$out/Casks"
cp "$T3CODE_NIGHTLY_CASK" "$out/Casks/$T3CODE_CASK_TOKEN.rb"

git -C "$out" init --quiet --initial-branch=main
git -C "$out" add "Casks/$T3CODE_CASK_TOKEN.rb"
GIT_AUTHOR_NAME="nix-config" \
  GIT_AUTHOR_EMAIL="nix-config@localhost" \
  GIT_AUTHOR_DATE="2000-01-01T00:00:00Z" \
  GIT_COMMITTER_NAME="nix-config" \
  GIT_COMMITTER_EMAIL="nix-config@localhost" \
  GIT_COMMITTER_DATE="2000-01-01T00:00:00Z" \
  git -C "$out" -c commit.gpgSign=false commit --quiet \
    --message="Pin T3 Code $T3CODE_RELEASE_VERSION"
