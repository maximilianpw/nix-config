#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
wrapper="$repo_root/scripts/with-github-auth.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
for tool in bash jq; do ln -s "$(command -v "$tool")" "$tmp/bin/$tool"; done
cat >"$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
[[ $* == 'config show --json' ]] || exit 99
[[ ${TEST_CONFIG_FAIL:-0} == 0 ]] || exit 1
printf '%s\n' "${TEST_SETTINGS}"
EOF
cat >"$tmp/bin/gh" <<'EOF'
#!/usr/bin/env bash
[[ $* == 'auth token --hostname github.com' ]] || exit 99
printf 'called\n' >>"$TEST_GH_CALLS"
[[ ${TEST_GH_FAIL:-0} == 0 ]] || exit 1
printf '%s\n' fixture-token
EOF
cat >"$tmp/bin/probe" <<'EOF'
#!/usr/bin/env bash
printf '%s' "${NIX_CONFIG:-}" >"$TEST_CAPTURE"
printf '%s\n' "$@" >"$TEST_ARGS"
exit "${TEST_EXIT:-0}"
EOF
chmod +x "$tmp/bin/nix" "$tmp/bin/gh" "$tmp/bin/probe"
export TEST_CAPTURE="$tmp/config" TEST_ARGS="$tmp/args" TEST_GH_CALLS="$tmp/gh-calls"
export TEST_SETTINGS='{"access-tokens":{"value":{"gitlab.com":"other-fixture"}}}'
export NIX_CONFIG='experimental-features = nix-command flakes'
original=$NIX_CONFIG
run() {
  PATH="$tmp/bin" bash "$wrapper" probe 'argument with spaces' >"$tmp/out" 2>"$tmp/err"
}
run
printf '%s\n%s' "$original" 'extra-access-tokens = github.com=fixture-token' >"$tmp/expected"
diff -u "$tmp/expected" "$TEST_CAPTURE"
grep -Fxq 'argument with spaces' "$TEST_ARGS"
[[ $NIX_CONFIG == "$original" ]]
! grep -q fixture-token "$tmp/out" "$tmp/err"

# Credentials must not appear even when invoked with shell tracing.
PATH="$tmp/bin" bash -x "$wrapper" probe >"$tmp/out" 2>"$tmp/err"
! grep -q fixture-token "$tmp/out" "$tmp/err"

# Effective settings may originate in nix.conf, not the environment.
export TEST_SETTINGS='{"access-tokens":{"value":{"github.com":"existing-fixture"}}}'
: >"$TEST_GH_CALLS"
run
[[ ! -s $TEST_GH_CALLS ]]
printf '%s' "$original" >"$tmp/expected"
diff -u "$tmp/expected" "$TEST_CAPTURE"

export TEST_SETTINGS='{"access-tokens":{"value":{}}}'
TEST_GH_FAIL=1 run
diff -u "$tmp/expected" "$TEST_CAPTURE"
grep -q 'API rate limits may apply' "$tmp/err"
rm "$tmp/bin/gh"
run
diff -u "$tmp/expected" "$TEST_CAPTURE"
grep -q 'API rate limits may apply' "$tmp/err"
TEST_CONFIG_FAIL=1 run
grep -q 'leaving authentication unchanged' "$tmp/err"

if TEST_EXIT=17 run; then exit 1; else [[ $? == 17 ]]; fi
if PATH="$tmp/bin" bash "$wrapper" >"$tmp/out" 2>"$tmp/err"; then
  exit 1
else
  [[ $? == 2 ]]
fi

echo 'GitHub update authentication tests passed'
