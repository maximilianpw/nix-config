#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
update_script="$repo_root/scripts/ci/update-packages.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

package=
for argument in "$@"; do
  package=$argument
done
printf '%s\n' "$package" >>"$TEST_ATTEMPTS"
[[ $package != ${TEST_FAIL_PACKAGE:-} ]]
EOF
chmod +x "$tmp/nix"
cat >"$tmp/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${TEST_UNAME:-Linux}"
EOF
chmod +x "$tmp/uname"
export PATH="$tmp:$PATH"
export TEST_ATTEMPTS="$tmp/attempts"

cat >"$tmp/expected-defaults" <<'EOF'
helium
obsidian
cliproxyapi
cua-driver
nextcloud-calendar
tunarr
EOF
"$update_script" --print-defaults >"$tmp/defaults"
diff -u "$tmp/expected-defaults" "$tmp/defaults"

: >"$TEST_ATTEMPTS"
TEST_UNAME=Darwin TEST_FAIL_PACKAGE=cua-driver "$update_script" --local >"$tmp/local-default.out"
printf '%s\n' cua-driver nextcloud-calendar >"$tmp/expected-local"
diff -u "$tmp/expected-local" "$TEST_ATTEMPTS"
grep -Fq '(skipped: cliproxyapi is Linux-only; CI updates it)' "$tmp/local-default.out"
grep -Fq '(skipped: cua-driver)' "$tmp/local-default.out"

: >"$TEST_ATTEMPTS"
TEST_UNAME=Linux TEST_FAIL_PACKAGE=obsidian "$update_script" --local >"$tmp/linux-default.out"
diff -u "$tmp/expected-defaults" "$TEST_ATTEMPTS"
grep -Fq '(skipped: obsidian)' "$tmp/linux-default.out"

: >"$TEST_ATTEMPTS"
export GITHUB_OUTPUT="$tmp/github-output"
PACKAGES='alpha beta gamma' TEST_FAIL_PACKAGE=beta "$update_script" >"$tmp/ci.out"
printf '%s\n' alpha beta gamma >"$tmp/expected-override"
diff -u "$tmp/expected-override" "$TEST_ATTEMPTS"
grep -Fxq 'failed_packages=beta' "$GITHUB_OUTPUT"

: >"$TEST_ATTEMPTS"
PACKAGES='one two three' TEST_FAIL_PACKAGE=two "$update_script" --local >"$tmp/local-override.out"
printf '%s\n' one two three >"$tmp/expected-local-override"
diff -u "$tmp/expected-local-override" "$TEST_ATTEMPTS"
grep -Fq '(skipped: two)' "$tmp/local-override.out"

if "$update_script" --unknown >"$tmp/unknown.out" 2>"$tmp/unknown.err"; then
  echo "unknown update-packages argument unexpectedly passed" >&2
  exit 1
fi
if "$update_script" --print-defaults extra >"$tmp/extra.out" 2>"$tmp/extra.err"; then
  echo "extra update-packages argument unexpectedly passed" >&2
  exit 1
fi

echo "package update inventory tests passed"
