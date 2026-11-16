#!/bin/sh
set -eu

line=
if [ "${1:-}" = "--line" ]; then
  line=${2:?"missing line number"}
  shift 2
fi

if [ "${1:-}" = "--" ]; then
  shift
fi

if [ "$#" -eq 0 ]; then
  printf '%s\n' "usage: lazygit-nvim-edit [--line LINE] -- PATH" >&2
  exit 64
fi

path=$1
shift
for part do
  path="$path $part"
done

if [ -n "${NVIM:-}" ]; then
  nvim --server "$NVIM" --remote-send "q"
  nvim --server "$NVIM" --remote-tab "$path"
  if [ -n "$line" ]; then
    nvim --server "$NVIM" --remote-send ":$line<CR>"
  fi
elif [ -n "$line" ]; then
  exec nvim +"$line" -- "$path"
else
  exec nvim -- "$path"
fi
