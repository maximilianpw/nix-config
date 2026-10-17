#!/usr/bin/env bash

: "${TMUX_RESURRECT_DIR:?TMUX_RESURRECT_DIR must be set}"
: "${DRY_RUN_CMD?DRY_RUN_CMD must be set by Home Manager activation}"

secure_resurrect_dir() {
  local dir="$1"
  if [ -d "$dir" ]; then
    $DRY_RUN_CMD find "$dir" -type d -exec chmod 700 {} +
    $DRY_RUN_CMD find "$dir" -type f -exec chmod 600 {} +
    $DRY_RUN_CMD rm -rf \
      "$dir/pane_contents.tar.gz" \
      "$dir/save/pane_contents" \
      "$dir/restore/pane_contents" \
      "$dir/restore/._pane_contents"
  fi
}

$DRY_RUN_CMD mkdir -p "$TMUX_RESURRECT_DIR"
secure_resurrect_dir "$TMUX_RESURRECT_DIR"
secure_resurrect_dir "$HOME/.tmux/resurrect"
