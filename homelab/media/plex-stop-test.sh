#!/usr/bin/env bash

set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

export CALL_LOG="$test_root/calls"
export PKILL_BIN="$test_root/pkill"
export TAIL_BIN="$test_root/tail"
printf '#!%s\n' "$BASH" > "$PKILL_BIN"
cat >> "$PKILL_BIN" <<'EOF'
printf 'pkill' >> "$CALL_LOG"
printf ' <%s>' "$@" >> "$CALL_LOG"
printf '\n' >> "$CALL_LOG"
exit "${PKILL_STATUS:-0}"
EOF
printf '#!%s\n' "$BASH" > "$TAIL_BIN"
cat >> "$TAIL_BIN" <<'EOF'
printf 'tail' >> "$CALL_LOG"
printf ' <%s>' "$@" >> "$CALL_LOG"
printf '\n' >> "$CALL_LOG"
exit "${TAIL_STATUS:-0}"
EOF
chmod +x "$PKILL_BIN" "$TAIL_BIN"

: > "$CALL_LOG"
bash "$here/plex-stop.sh"
bash "$here/plex-stop.sh" ""
test ! -s "$CALL_LOG"

for invalid in 0 1 -2 01 abc '42; echo unsafe'; do
  if bash "$here/plex-stop.sh" "$invalid" > /dev/null 2>&1; then
    echo "Plex stop unexpectedly accepted invalid PID: $invalid" >&2
    exit 1
  else
    test "$?" = 2
  fi
done
if bash "$here/plex-stop.sh" 1234 5678 > /dev/null 2>&1; then
  echo "Plex stop unexpectedly accepted multiple PIDs" >&2
  exit 1
else
  test "$?" = 2
fi
test ! -s "$CALL_LOG"

cat > "$test_root/expected" <<'EOF'
pkill <--signal> <TERM> <--parent> <1234>
tail <--pid=1234> <--sleep-interval=0.1> <--follow> </dev/null>
EOF
bash "$here/plex-stop.sh" 1234
cmp "$test_root/expected" "$CALL_LOG"

: > "$CALL_LOG"
PKILL_STATUS=1 bash "$here/plex-stop.sh" 1234 2> "$test_root/stderr"
grep -F 'Plex stop: no application child signalled' "$test_root/stderr"
cmp "$test_root/expected" "$CALL_LOG"

: > "$CALL_LOG"
if PKILL_STATUS=3 bash "$here/plex-stop.sh" 1234; then
  echo "Plex stop unexpectedly ignored a signalling failure" >&2
  exit 1
else
  test "$?" = 3
fi
printf 'pkill <--signal> <TERM> <--parent> <1234>\n' > "$test_root/expected-error"
cmp "$test_root/expected-error" "$CALL_LOG"

: > "$CALL_LOG"
if TAIL_STATUS=7 bash "$here/plex-stop.sh" 1234; then
  echo "Plex stop unexpectedly ignored a wait failure" >&2
  exit 1
else
  test "$?" = 7
fi
cmp "$test_root/expected" "$CALL_LOG"

echo "Plex graceful stop tests passed"
