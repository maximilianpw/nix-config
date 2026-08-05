#!/usr/bin/env bash

: "${FOCUS_OR_LAUNCH_AWK:?FOCUS_OR_LAUNCH_AWK must be set}"

class="$1"
shift

if hyprctl clients | "$FOCUS_OR_LAUNCH_AWK" -v class="$class" '
  $1 == "class:" {
    $1 = ""
    sub(/^ /, "")
    if ($0 == class) found = 1
  }
  END { exit found ? 0 : 1 }
'; then
  hyprctl dispatch focuswindow "class:$class"
else
  exec "$@"
fi
