#!/usr/bin/env bash
# Rollback must pass an explicit action to nixos-rebuild (without one it only
# prints its manual and exits 0) and re-run Kim's homelab checks afterwards.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
export TEST_COMMANDS=$tmp/commands

cat > "$tmp/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TEST_OS"
EOF
cat > "$tmp/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >> "$TEST_COMMANDS"
EOF
cat > "$tmp/homelab-check" <<'EOF'
#!/usr/bin/env bash
echo homelab-check >> "$TEST_COMMANDS"
exit "${TEST_CHECK_STATUS:-0}"
EOF
chmod +x "$tmp/bin/"* "$tmp/homelab-check"

run_rollback() {
    export TEST_OS=$1 NIX_CONFIG_HOST=$2
    : > "$TEST_COMMANDS"
    PATH="$tmp/bin:$PATH" HOMELAB_CHECK_BIN="$tmp/homelab-check" \
        HOMELAB_CHECK_ATTEMPTS=1 CURRENT_SYSTEM_LINK="$tmp/missing" \
        bash "$repo_root/scripts/nixos-rollback.sh" > "$tmp/out" 2>&1
}

run_rollback Linux kim
diff -u <(printf '%s\n' 'sudo nixos-rebuild switch --rollback' homelab-check) "$TEST_COMMANDS"

run_rollback Linux cuno
diff -u <(printf '%s\n' 'sudo nixos-rebuild switch --rollback') "$TEST_COMMANDS"

run_rollback Darwin joyce
diff -u <(printf '%s\n' 'sudo darwin-rebuild --rollback') "$TEST_COMMANDS"

if TEST_CHECK_STATUS=1 run_rollback Linux kim; then
    echo "rollback hid a failed homelab check" >&2
    exit 1
fi

echo "nixos rollback tests passed"
