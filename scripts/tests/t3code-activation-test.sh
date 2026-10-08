#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/sudo" <<'EOF'
#!/usr/bin/env bash
while [[ $1 != -- ]]; do shift; done
shift
exec "$@"
EOF
cat > "$tmp/brew" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'list --cask -1' ]] || exit 90
[[ ${BREW_FAIL:-0} == 0 ]] || exit 1
printf '%s\n' "${INSTALLED_CASKS:-}"
EOF
chmod +x "$tmp/bin/sudo" "$tmp/brew"
export PATH="$tmp/bin:$PATH"
export T3CODE_SYSTEM_USER=tester T3CODE_BREW_BIN="$tmp/brew"
for cask in maxpw-t3-code-nightly t3-code t3-code@nightly maxpw/t3code-nightly/maxpw-t3-code-nightly; do
  if INSTALLED_CASKS="$cask" bash "$repo_root/scripts/t3code-pre-activation.sh" 2> "$tmp/err"; then
    echo "migration guard accepted installed cask $cask" >&2
    exit 1
  fi
  grep -q 'WITHOUT --zap' "$tmp/err"
done
INSTALLED_CASKS=unrelated bash "$repo_root/scripts/t3code-pre-activation.sh"
bash "$repo_root/scripts/t3code-pre-activation.sh"
T3CODE_BREW_BIN="$tmp/missing" bash "$repo_root/scripts/t3code-pre-activation.sh"
if BREW_FAIL=1 bash "$repo_root/scripts/t3code-pre-activation.sh" 2> "$tmp/err"; then
  echo 'migration guard accepted failed brew query' >&2
  exit 1
fi
grep -q 'cannot inspect installed casks' "$tmp/err"
echo 'T3 Code migration guard tests passed'
