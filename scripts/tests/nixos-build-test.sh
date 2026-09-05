#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fixture="$tmp/config with spaces"
mkdir -p "$tmp/bin" "$fixture/scripts/lib"
cp "$repo_root/Makefile" "$fixture/Makefile"
cp "$repo_root/scripts/nixos-build.sh" "$fixture/scripts/"
cp "$repo_root/scripts/lib/host-detect.sh" "$fixture/scripts/lib/"
export TEST_COMMANDS=$tmp/commands TEST_CONFIG_DIR=$fixture

cat > "$tmp/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TEST_OS"
EOF
cat > "$tmp/bin/hostname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TEST_HOST"
EOF
cat > "$tmp/bin/whoami" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$TEST_USER"
EOF
cat > "$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$1" >> "$TEST_COMMANDS"
case "$1" in
  eval)
    [[ $# == 3 && $2 == --raw && $3 == "path:$TEST_CONFIG_DIR#lib.hosts.\"$TEST_EXPECT_HOST\".os" ]]
    printf '%s' "$TEST_KIND"
    exit "${TEST_EVAL_STATUS:-0}"
    ;;
  build)
    [[ $# == 2 ]]
    printf '%s\n' "$2" >> "$TEST_COMMANDS"
    exit "${TEST_BUILD_STATUS:-0}"
    ;;
  *) exit 90 ;;
esac
EOF
cat > "$tmp/bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo 'unexpected privileged action' >> "$TEST_COMMANDS"
exit 90
EOF
cp "$tmp/bin/sudo" "$tmp/bin/nh"
cp "$tmp/bin/sudo" "$tmp/bin/alejandra"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"

run_case() {
  export TEST_OS=$1 TEST_HOST=$2 TEST_USER=$3 TEST_KIND=$4 TEST_EXPECT_HOST=$5
  export NIX_CONFIG_TEST_WSL=$6 NIX_CONFIG_HOST=${7:-}
  : > "$TEST_COMMANDS"
  make --no-print-directory -C "$fixture" build > "$tmp/out" 2> "$tmp/err"
}

expect_build() {
  local target=$1
  shift
  run_case "$@"
  printf '%s\n' eval build "path:$fixture#$target" > "$tmp/expected"
  diff -u "$tmp/expected" "$TEST_COMMANDS"
}

expect_build nixosConfigurations.kim.config.system.build.toplevel Linux main-pc maxpw nixos kim 0
expect_build nixosConfigurations.cuno.config.system.build.toplevel Linux arbitrary maxpw nixos-wsl cuno 1
expect_build darwinConfigurations.joyce.system Darwin unrelated max-vev darwin joyce 0
expect_build darwinConfigurations.joyce.system Darwin unrelated stranger darwin joyce 0 joyce
expect_build nixosConfigurations.cuno.config.system.build.toplevel Linux arbitrary maxpw nixos-wsl cuno 0 wsl

expect_no_build() {
  if run_case "$@"; then
    echo "invalid build target unexpectedly succeeded" >&2
    exit 1
  fi
  [[ $(cat "$TEST_COMMANDS") != *build* ]]
  [[ $(cat "$TEST_COMMANDS") != *'unexpected privileged action'* ]]
}
expect_no_build Darwin unknown stranger darwin joyce 0
expect_no_build Linux arbitrary maxpw nixos kim 0 '../kim'
expect_no_build Linux kim maxpw darwin kim 0
TEST_EVAL_STATUS=17 expect_no_build Linux unknown maxpw nixos unknown 0

if TEST_BUILD_STATUS=19 run_case Linux kim maxpw nixos kim 0; then
  echo "make build hid a build failure" >&2
  exit 1
fi
# Direct entry point retains the exact nix build exit status.
set +e
TEST_BUILD_STATUS=19 bash "$fixture/scripts/nixos-build.sh" "$fixture" >/dev/null
status=$?
set -e
[[ $status == 19 ]]

echo "nixos build tests passed"
