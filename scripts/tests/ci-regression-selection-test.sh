#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export REAL_NIX_BIN
REAL_NIX_BIN=$(command -v nix)
export TEST_BUILD_ARGS=$tmp/build-args
export TEST_CHECKS='{ actual-config-regression = null; executor-config-regression = null; future-regression = null; eval-kim = null; pre-commit-check = null; regression-extra = null; }'

cat > "$tmp/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  eval)
    [[ $2 == --raw && $3 == .#checks.x86_64-linux && $4 == --apply ]]
    # Exercise the production selector with a pure fixture: no flake fetch or
    # derivation build, including non-regression names that must be excluded.
    "$REAL_NIX_BIN" eval --offline --raw --expr "($5) $TEST_CHECKS"
    exit "${TEST_EVAL_STATUS:-0}"
    ;;
  build)
    printf '%s\n' "$@" > "$TEST_BUILD_ARGS"
    exit "${TEST_BUILD_STATUS:-0}"
    ;;
  *) exit 90 ;;
esac
EOF
chmod +x "$tmp/nix"
export PATH="$tmp:$PATH"

bash "$repo_root/scripts/ci/build-regression-checks.sh"
printf '%s\n' build --no-link \
  .#checks.x86_64-linux.actual-config-regression \
  .#checks.x86_64-linux.executor-config-regression \
  .#checks.x86_64-linux.future-regression > "$tmp/expected"
diff -u "$tmp/expected" "$TEST_BUILD_ARGS"

rm "$TEST_BUILD_ARGS"
if TEST_EVAL_STATUS=17 bash "$repo_root/scripts/ci/build-regression-checks.sh"; then
  echo "evaluation failure after partial output unexpectedly passed" >&2
  exit 1
fi
[[ ! -e $TEST_BUILD_ARGS ]]

if TEST_CHECKS='{}' bash "$repo_root/scripts/ci/build-regression-checks.sh"; then
  echo "empty regression selection unexpectedly passed" >&2
  exit 1
fi
[[ ! -e $TEST_BUILD_ARGS ]]

set +e
TEST_BUILD_STATUS=19 bash "$repo_root/scripts/ci/build-regression-checks.sh"
status=$?
set -e
[[ $status == 19 ]]

# Make must parse more than the first script before reaching ShellCheck.
mkdir -p "$tmp/syntax/scripts"
cp "$repo_root/Makefile" "$tmp/syntax/Makefile"
printf '#!/usr/bin/env bash\ntrue\n' > "$tmp/syntax/scripts/a-valid.sh"
printf 'if\n' > "$tmp/syntax/scripts/z-invalid.sh"
cat > "$tmp/shellcheck" <<'EOF'
#!/usr/bin/env bash
touch "$TEST_BUILD_ARGS"
exit 1
EOF
chmod +x "$tmp/shellcheck"
rm "$TEST_BUILD_ARGS"
if make --no-print-directory -C "$tmp/syntax" check-scripts > "$tmp/syntax.out" 2>&1; then
  echo "syntax error in a later script unexpectedly passed" >&2
  exit 1
fi
[[ ! -e $TEST_BUILD_ARGS ]]
grep -Fq z-invalid.sh "$tmp/syntax.out"

echo "CI regression selection tests passed"
