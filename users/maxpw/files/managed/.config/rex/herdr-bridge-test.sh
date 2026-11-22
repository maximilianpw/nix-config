#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
bridge="$here/herdr-bridge.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/rex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$REX_CALLS"
case "$2" in
  project_open) printf '{"session_id":"session:fixture"}\n' ;;
  *) printf '{"result":{"panes":[]}}\n' ;;
esac
EOF
chmod +x "$tmp/rex"
export PATH="$tmp:$PATH" REX_CALLS="$tmp/calls"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[[ $("$bridge" workspace list) == '{"result":{"workspaces":[]}}' ]] || fail "workspace list"

[[ $("$bridge" pane list) == '{"result":{"panes":[]}}' ]] || fail "pane list output"
[[ $(tail -n 1 "$REX_CALLS") == "do $here/herdr-panes.lua" ]] || fail "pane list runs the Lua script beside the bridge"

opened=$("$bridge" worktree open --cwd /repo --path "/repo.jj-a b" --label "jj: a b" --focus)
[[ $opened == '{"result":{"session_id":"session:fixture"}}' ]] || fail "worktree open output: $opened"
[[ $(tail -n 1 "$REX_CALLS") == "do project_open dir=/repo.jj-a b" ]] || fail "worktree open hands the checkout path to project_open"

status=0
"$bridge" worktree open --cwd /repo 2> /dev/null || status=$?
[[ $status == 64 ]] || fail "worktree open without --path exits 64, got $status"

status=0
"$bridge" plugin config-dir 2> /dev/null || status=$?
[[ $status == 64 ]] || fail "unsupported command exits 64, got $status"

echo "herdr-bridge-test: ok"
