#!/usr/bin/env bash

set -euo pipefail

: "${HERDR_SESSION_PICKER_LOCAL_HOST:?hs requires HERDR_SESSION_PICKER_LOCAL_HOST}"

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
sessions_file="$tmpdir/sessions.tsv"
hosts_file="$HOME/.config/fleet/hosts.json"

if local_sessions=$(herdr session list --json 2>/dev/null); then
  jq -r '.sessions[].name | ["local", .] | @tsv' \
    <<<"$local_sessions" >"$sessions_file"
else
  : >"$sessions_file"
fi

remote_hosts=()
if [[ -f "$hosts_file" ]]; then
  mapfile -t remote_hosts < <(
    jq -r --arg current "$HERDR_SESSION_PICKER_LOCAL_HOST" \
      'keys[] | select(. != $current)' "$hosts_file"
  )
fi

remote_files=()
index=0
for host in "${remote_hosts[@]}"; do
  remote_file="$tmpdir/remote-$index.tsv"
  remote_files+=("$remote_file")
  index=$((index + 1))

  (
    if remote_sessions=$(
      timeout 6 ssh \
        -o BatchMode=yes \
        -o ConnectTimeout=3 \
        "$host" herdr session list --json 2>/dev/null
    ); then
      jq -r --arg host "$host" \
        '.sessions[].name | [$host, .] | @tsv' \
        <<<"$remote_sessions" >"$remote_file"
    fi
  ) &
done
wait || true

for remote_file in "${remote_files[@]}"; do
  [[ -f "$remote_file" ]] && cat "$remote_file" >>"$sessions_file"
done

if [[ ! -s "$sessions_file" ]]; then
  echo "hs: no local or reachable remote Herdr sessions found" >&2
  exit 1
fi

selection=$(
  fzf \
    --delimiter=$'\t' \
    --with-nth=1,2 \
    --header=$'LOCATION\tSESSION' \
    --prompt='Herdr session: ' \
    <"$sessions_file"
) || exit 0

[[ -n "$selection" ]] || exit 0
location="${selection%%$'\t'*}"
session="${selection#*$'\t'}"

if [[ "$location" == "local" ]]; then
  exec herdr session attach "$session"
fi
exec herdr --remote "$location" --session "$session"
