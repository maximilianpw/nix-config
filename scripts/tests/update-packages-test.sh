#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
update_script="$repo_root/scripts/ci/update-packages.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export REAL_BASH
REAL_BASH=$(command -v bash)

cat >"$tmp/nix" <<'EOF'
#!/bin/sh
for argument in "$@"; do package=$argument; done
printf '%s\n' "$package" >>"$TEST_ATTEMPTS"
printf '%s\n' "$*" >>"$TEST_COMMANDS"
[ "$package" != "${TEST_FAIL_PACKAGE:-}" ]
EOF
cat >"$tmp/python3" <<'EOF'
#!/bin/sh
[ "$1" = scripts/dev/update-source-pins.py ] || exit 99
printf '%s\n' "$2" >>"$TEST_ATTEMPTS"
[ "$2" != "${TEST_FAIL_PACKAGE:-}" ]
EOF
cat >"$tmp/bash" <<'EOF'
#!/bin/sh
if [ "$1" = packages/scripts/update-cua-driver.sh ]; then
  printf '%s\n' cua-driver >>"$TEST_ATTEMPTS"
  [ cua-driver != "${TEST_FAIL_PACKAGE:-}" ]
else
  exec "$REAL_BASH" "$@"
fi
EOF
cat >"$tmp/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${TEST_UNAME:-Linux}"
EOF
chmod +x "$tmp/nix" "$tmp/python3" "$tmp/bash" "$tmp/uname"
export PATH="$tmp:$PATH"
export TEST_ATTEMPTS="$tmp/attempts" TEST_COMMANDS="$tmp/commands"

cat >"$tmp/expected-defaults" <<'EOF'
helium
obsidian
cliproxyapi
cua-driver
tunarr
herdr-core
cloudflared
plex
EOF
"$update_script" --print-defaults >"$tmp/defaults"
diff -u "$tmp/expected-defaults" "$tmp/defaults"

for platform in Darwin Linux; do
  : >"$TEST_ATTEMPTS"
  : >"$TEST_COMMANDS"
  TEST_UNAME=$platform "$update_script" --local >"$tmp/$platform.out"
  diff -u "$tmp/expected-defaults" "$TEST_ATTEMPTS"
  grep -Fxq 'run .#nix-update -- --flake --system x86_64-linux --use-update-script helium' "$TEST_COMMANDS"
  grep -Fxq 'run .#nix-update -- --flake --override-filename flake.nix cloudflared' "$TEST_COMMANDS"

  : >"$TEST_ATTEMPTS"
  if TEST_UNAME=$platform TEST_FAIL_PACKAGE=obsidian "$update_script" --local >"$tmp/failure.out" 2>"$tmp/failure.err"; then
    echo 'a failed package update unexpectedly passed' >&2
    exit 1
  fi
  diff -u "$tmp/expected-defaults" "$TEST_ATTEMPTS"
  grep -Fq 'Package updates incomplete: obsidian' "$tmp/failure.err"
done

: >"$TEST_ATTEMPTS"
export GITHUB_OUTPUT="$tmp/github-output"
PACKAGES='alpha beta gamma' TEST_FAIL_PACKAGE=beta "$update_script" >"$tmp/ci.out" 2>"$tmp/ci.err"
printf '%s\n' alpha beta gamma >"$tmp/expected-override"
diff -u "$tmp/expected-override" "$TEST_ATTEMPTS"
grep -Fxq 'failed_packages=beta' "$GITHUB_OUTPUT"

: >"$TEST_ATTEMPTS"
if PACKAGES='one two three' TEST_FAIL_PACKAGE=two "$update_script" --local >"$tmp/local-override.out" 2>"$tmp/local-override.err"; then
  echo 'a failed explicitly selected package unexpectedly passed' >&2
  exit 1
fi
printf '%s\n' one two three >"$tmp/expected-local-override"
diff -u "$tmp/expected-local-override" "$TEST_ATTEMPTS"
grep -Fq 'Package updates incomplete: two' "$tmp/local-override.err"

if "$update_script" --unknown >"$tmp/unknown.out" 2>"$tmp/unknown.err"; then
  echo "unknown update-packages argument unexpectedly passed" >&2
  exit 1
fi
if "$update_script" --print-defaults extra >"$tmp/extra.out" 2>"$tmp/extra.err"; then
  echo "extra update-packages argument unexpectedly passed" >&2
  exit 1
fi

echo "package update inventory tests passed"
