#!/bin/sh

# Keep Herdr as the only multiplexer: panes in the local "kim" workspace
# start a plain SSH shell, while every other workspace starts Fish normally.
if [ -n "${HERDR_WORKSPACE_ID:-}" ] && [ "$(hostname -s)" != "kim" ]; then
  workspace_label=$(
    herdr workspace get "$HERDR_WORKSPACE_ID" 2>/dev/null |
      jq -r '.result.workspace.label // empty' 2>/dev/null
  )

  if [ "$workspace_label" = "kim" ]; then
    exec fleet shell kim
  fi
fi

exec fish "$@"
