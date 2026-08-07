#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
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
((attempt >= SUCCEED_ON_ATTEMPT))
EOF
cat > "$fake_sleep" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >> "$SLEEP_FILE"
EOF
chmod +x "$fake_check" "$fake_sleep"

ATTEMPT_FILE="$attempt_file" SLEEP_FILE="$sleep_file" SUCCEED_ON_ATTEMPT=3 \
  HOMELAB_CHECK_BIN="$fake_check" SLEEP_BIN="$fake_sleep" HOMELAB_CHECK_ATTEMPTS=4 \
  HOMELAB_CHECK_RETRY_SECONDS=7 "$script_dir/post-switch-homelab-check.sh" /nix/store/previous >/dev/null
test "$(< "$attempt_file")" = 3
test "$(wc -l < "$sleep_file")" = 2
test "$(head -n 1 "$sleep_file")" = 7

rm -f "$attempt_file" "$sleep_file"
if ATTEMPT_FILE="$attempt_file" SLEEP_FILE="$sleep_file" SUCCEED_ON_ATTEMPT=99 \
  HOMELAB_CHECK_BIN="$fake_check" SLEEP_BIN="$fake_sleep" HOMELAB_CHECK_ATTEMPTS=2 \
  HOMELAB_CHECK_RETRY_SECONDS=0 CURRENT_SYSTEM_LINK="$test_root/missing" \
  "$script_dir/post-switch-homelab-check.sh" /nix/store/previous >/dev/null 2>&1; then
  echo "post-switch check unexpectedly accepted repeated failures" >&2
  exit 1
fi
test "$(< "$attempt_file")" = 2

echo "post-switch homelab check tests passed"
