#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/nix-config/scripts/lib"
cp "$repo_root/scripts/lib/host-detect.sh" "$tmp/home/nix-config/scripts/lib/"
export TEST_COMMANDS=$tmp/commands
export REAL_READLINK
REAL_READLINK=$(command -v readlink)

cat > "$tmp/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TEST_OS"
EOF
cat > "$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  --version) printf 'nix (fixture)\n' ;;
  eval)
    echo validate >> "$TEST_COMMANDS"
    printf '%s' "$TEST_KIND"
    exit "${TEST_EVAL_STATUS:-0}"
    ;;
  *) exit 90 ;;
esac
EOF
cat > "$tmp/bin/readlink" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${2:-} == /etc/nixos ]]; then
  echo link-check >> "$TEST_COMMANDS"
fi
exec "$REAL_READLINK" "$@"
EOF
cat > "$tmp/bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo privileged >> "$TEST_COMMANDS"
# Never execute a privileged command in this test, even on an unexpected path.
exit 0
EOF
cat > "$tmp/bin/nh" <<'EOF'
#!/usr/bin/env bash
echo nh >> "$TEST_COMMANDS"
exit 91
EOF
cat > "$tmp/bin/noop" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
for command in git alejandra xcode-select brew; do cp "$tmp/bin/noop" "$tmp/bin/$command"; done
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" HOME=$tmp/home NIX_CONFIG_STATE_DIR=$tmp/state
export NIX_CONFIG_TEST_WSL=0 SKIP_SOPS_CHECK=1
unset SKIP_ETC_NIXOS_LINK

assert_no_command() {
  if grep -Fxq "$1" "$TEST_COMMANDS"; then
    echo "unexpected command: $1" >&2
    exit 1
  fi
}

bootstrap_case() {
  export TEST_OS=$1 TEST_KIND=$2 NIX_CONFIG_HOST=$3
  shift 3
  : > "$TEST_COMMANDS"
  printf 'n\n' | bash "$repo_root/scripts/bootstrap.sh" --skip-clone "$@" > "$tmp/out" 2> "$tmp/err"
}

if TEST_EVAL_STATUS=17 bootstrap_case Linux nixos unknown; then
  echo "unknown bootstrap target unexpectedly passed" >&2
  exit 1
fi
[[ $(cat "$TEST_COMMANDS") == validate ]]

if bootstrap_case Linux darwin joyce; then
  echo "incompatible bootstrap target unexpectedly passed" >&2
  exit 1
fi
[[ $(cat "$TEST_COMMANDS") == validate ]]

bootstrap_case Darwin darwin joyce
[[ $(cat "$TEST_COMMANDS") == validate ]]

bootstrap_case Linux nixos kim
# Whether /etc/nixos exists on the test host or not, even inspecting it for
# upkeep must follow compatible inventory validation. sudo above is inert.
[[ $(head -n 2 "$TEST_COMMANDS") == $'validate\nlink-check' ]]
assert_no_command nh

bootstrap_case Linux nixos kim --dry-run
assert_no_command privileged
assert_no_command nh

export TEST_OS=Darwin TEST_KIND=darwin NIX_CONFIG_HOST=joyce
: > "$TEST_COMMANDS"
if bash "$repo_root/scripts/nixos-rebuild.sh" > "$tmp/out" 2> "$tmp/err"; then
  echo "rebuild unexpectedly ignored mock nh failure" >&2
  exit 1
fi
grep -Fxq nh "$TEST_COMMANDS"
assert_no_command link-check
assert_no_command privileged

echo "host link preflight tests passed"
