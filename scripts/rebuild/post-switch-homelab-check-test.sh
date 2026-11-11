#!/usr/bin/env bash

set -euo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fake_check="$test_root/homelab-check"
fake_sleep="$test_root/sleep"
attempt_file="$test_root/attempts"
sleep_file="$test_root/sleeps"

cat > "$fake_check" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
attempt=0
[[ ! -f $ATTEMPT_FILE ]] || attempt=$(< "$ATTEMPT_FILE")
attempt=$((attempt + 1))
printf '%s\n' "$attempt" > "$ATTEMPT_FILE"
echo "== report section =="
((attempt >= SUCCEED_ON_ATTEMPT)) && exit 0
echo "FAIL: ${FAIL_MESSAGE:-target pending}" >&2
exit 1
EOF
cat > "$fake_sleep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >> "$SLEEP_FILE"
EOF
chmod +x "$fake_check" "$fake_sleep"

ATTEMPT_FILE="$attempt_file" SLEEP_FILE="$sleep_file" SUCCEED_ON_ATTEMPT=3 \
  HOMELAB_CHECK_BIN="$fake_check" SLEEP_BIN="$fake_sleep" HOMELAB_CHECK_ATTEMPTS=4 \
  HOMELAB_CHECK_RETRY_SECONDS=7 "$here/post-switch-homelab-check.sh" /nix/store/previous \
  > "$test_root/out" 2>&1
test "$(< "$attempt_file")" = 3
diff -u - "$test_root/out" <<'EOF'
Homelab check 1/4 failed (retrying every 7s):
  FAIL: target pending
Homelab check 2/4: still failing
Post-switch homelab check passed (attempt 3/4)
EOF
[[ $(wc -l < "$sleep_file") -eq 2 ]]
test "$(head -n 1 "$sleep_file")" = 7

rm -f "$attempt_file" "$sleep_file"
if ATTEMPT_FILE="$attempt_file" SLEEP_FILE="$sleep_file" SUCCEED_ON_ATTEMPT=99 \
  HOMELAB_CHECK_BIN="$fake_check" SLEEP_BIN="$fake_sleep" HOMELAB_CHECK_ATTEMPTS=2 \
  HOMELAB_CHECK_RETRY_SECONDS=0 CURRENT_SYSTEM_LINK="$test_root/missing" \
  FAIL_MESSAGE="unit down" "$here/post-switch-homelab-check.sh" /nix/store/previous \
  > "$test_root/out" 2>&1; then
  echo "post-switch check unexpectedly accepted repeated failures" >&2
  exit 1
fi
test "$(< "$attempt_file")" = 2
grep -Fxq '== report section ==' "$test_root/out"
grep -Fxq 'Post-switch homelab check failed after 2 attempts' "$test_root/out"
test "$(grep -c 'FAIL: unit down' "$test_root/out")" = 2

# Public-ingress probes may wait five minutes for their first scrape after
# Prometheus starts. The default retry budget must cover that interval.
rm -f "$attempt_file" "$sleep_file"
ATTEMPT_FILE="$attempt_file" SLEEP_FILE="$sleep_file" SUCCEED_ON_ATTEMPT=32 \
  HOMELAB_CHECK_BIN="$fake_check" SLEEP_BIN="$fake_sleep" \
  "$here/post-switch-homelab-check.sh" /nix/store/previous >/dev/null
test "$(< "$attempt_file")" = 32
[[ $(wc -l < "$sleep_file") -eq 31 ]]
test "$(head -n 1 "$sleep_file")" = 10

# A terminal gets one redrawn status line with a per-second countdown; the
# rebuild log keeps only the lines that were left on screen.
rm -f "$attempt_file" "$sleep_file"
ATTEMPT_FILE="$attempt_file" SLEEP_FILE="$sleep_file" SUCCEED_ON_ATTEMPT=3 \
  HOMELAB_CHECK_BIN="$fake_check" SLEEP_BIN="$fake_sleep" HOMELAB_CHECK_ATTEMPTS=4 \
  HOMELAB_CHECK_RETRY_SECONDS=2 HOMELAB_CHECK_LIVE=1 \
  "$here/post-switch-homelab-check.sh" /nix/store/previous > "$test_root/out" 2>&1
test "$(sort -u "$sleep_file")" = 1
[[ $(wc -l < "$sleep_file") -eq 4 ]]
grep -q $'\r\033\[2K' "$test_root/out"
grep -Fq 'retrying in 2s' "$test_root/out"
# shellcheck source=scripts/rebuild/lib/rebuild-log.sh
source "$here/lib/rebuild-log.sh"
clean_rebuild_log < "$test_root/out" | diff -u - <(cat <<'EXPECTED'
Homelab check 1/4 failed (retrying every 2s):
  FAIL: target pending
Post-switch homelab check passed (attempt 3/4)
EXPECTED
)

echo "post-switch homelab check tests passed"
