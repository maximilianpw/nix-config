#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export TEST_UPDATE_LOG="$tmp/updates" GITHUB_OUTPUT="$tmp/output"
export TEST_PACKAGE_SELECTION='future-package nextcloud-calendar'
export PACKAGES=''

cat > "$tmp/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  eval)
    [[ $* == 'eval --raw .#lib.packageUpdates' ]]
    printf '%s' "$TEST_PACKAGE_SELECTION"
    exit "${TEST_EVAL_STATUS:-0}"
    ;;
  run)
    [[ $2 == .#nix-update && $3 == -- && $4 == --flake ]]
    printf '%s\n' "${*:5}" >> "$TEST_UPDATE_LOG"
    exit "${TEST_UPDATE_STATUS:-0}"
    ;;
  *) exit 90 ;;
esac
EOF
chmod +x "$tmp/nix"
export PATH="$tmp:$PATH"

run_update() {
  if [[ $entrypoint == local ]]; then
    make --no-print-directory -C "$repo_root" update-packages
  else
    bash "$repo_root/scripts/ci/update-packages.sh"
  fi
}

for entrypoint in local ci; do
  rm -f "$TEST_UPDATE_LOG"
  run_update
  prefix=''
  [[ $entrypoint != ci ]] || prefix='--use-update-script '
  printf '%s\n' "${prefix}future-package" "${prefix}nextcloud-calendar" > "$tmp/expected"
  diff -u "$tmp/expected" "$TEST_UPDATE_LOG"

  rm "$TEST_UPDATE_LOG"
  if TEST_EVAL_STATUS=17 run_update; then
    echo "$entrypoint ignored a registry evaluation failure" >&2
    exit 1
  fi
  [[ ! -e $TEST_UPDATE_LOG ]]
  if TEST_PACKAGE_SELECTION='' run_update; then
    echo "$entrypoint accepted an empty registry" >&2
    exit 1
  fi
  [[ ! -e $TEST_UPDATE_LOG ]]
done

# A dispatch override bypasses discovery and retains CI's failure reporting.
PACKAGES=chosen-package TEST_EVAL_STATUS=17 TEST_UPDATE_STATUS=19 run_update
printf '%s\n' '--use-update-script chosen-package' > "$tmp/expected"
diff -u "$tmp/expected" "$TEST_UPDATE_LOG"
grep -Fxq 'failed_packages=chosen-package' "$GITHUB_OUTPUT"

echo "Package update entrypoint tests passed"
