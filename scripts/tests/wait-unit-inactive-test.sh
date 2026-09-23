#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/scripts/wait-unit-inactive.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# The unit reports active for ACTIVE_POLLS polls, then inactive.
cat > "$tmp/systemctl" <<'EOF'
#!/usr/bin/env bash
count=$(($(cat "$POLL_FILE" 2>/dev/null || echo 0) + 1))
echo "$count" > "$POLL_FILE"
((count <= ACTIVE_POLLS))
EOF
chmod +x "$tmp/systemctl"

export SYSTEMCTL_BIN=$tmp/systemctl
export SLEEP_BIN
SLEEP_BIN=$(command -v true)
export WAIT_UNIT=example.service
export WAIT_MAX_ATTEMPTS=3
export POLL_FILE=$tmp/polls

# A unit that finishes within the limit is waited for.
ACTIVE_POLLS=2 bash "$script"
[[ $(cat "$POLL_FILE") == 3 ]]

# A unit that never finishes times out instead of blocking the backup.
rm -f "$POLL_FILE"
if ACTIVE_POLLS=100 bash "$script" 2> "$tmp/err"; then
  echo "a stuck unit unexpectedly passed" >&2
  exit 1
fi
grep -Fq 'Timed out waiting for example.service' "$tmp/err"

echo "wait-unit-inactive tests passed"
