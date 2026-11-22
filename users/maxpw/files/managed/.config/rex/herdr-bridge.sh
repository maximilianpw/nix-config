#!/bin/sh
# herdr-jj drives its host through a `herdr` binary (HERDR_BIN_PATH). This
# answers the three calls it makes, with Rex as the host.
set -eu

here=$(dirname "$0")

case "${1-} ${2-}" in
"pane list")
  exec rex "do" "$here/herdr-panes.lua"
  ;;
"workspace list")
  # Rex binds no session to a checkout; `pane list` already reports every
  # terminal's directory, which is what archiving checks.
  printf '{"result":{"workspaces":[]}}\n'
  ;;
"worktree open")
  shift 2
  path=
  while [ $# -gt 0 ]; do
    if [ "$1" = --path ]; then
      path=${2-}
    fi
    shift
  done
  [ -n "$path" ] || {
    echo "herdr-bridge: worktree open needs --path" >&2
    exit 64
  }
  opened=$(rex "do" project_open "dir=$path")
  printf '{"result":%s}\n' "$opened"
  ;;
*)
  echo "herdr-bridge: unsupported herdr command: $*" >&2
  exit 64
  ;;
esac
