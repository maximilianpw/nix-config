#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/scripts/dev" "$tmp/scripts/ci" "$tmp/packages"
cp "$repo_root/Makefile" "$tmp/Makefile"

cat >"$tmp/scripts/dev/update-source-pins.py" <<'EOF'
import os
from pathlib import Path
import sys
name = sys.argv[1] if len(sys.argv) > 1 else "t3code"
with Path(os.environ["TEST_CALLS"]).open("a") as output:
    output.write(name + "\n")
sys.exit(1 if name in os.environ.get("TEST_FAILURES", "").split() else 0)
EOF
cp "$tmp/scripts/dev/update-source-pins.py" "$tmp/packages/update-t3code.py"
cat >"$tmp/scripts/ci/update-packages.sh" <<'EOF'
#!/bin/sh
[ -z "${PACKAGES:-}" ] || exit 99
printf 'packages\n' >>"$TEST_CALLS"
case " ${TEST_FAILURES:-} " in *' packages '*) exit 1 ;; esac
EOF
cat >"$tmp/scripts/dev/nvim-plugin-pins.sh" <<'EOF'
#!/bin/sh
[ "$*" = --all ] || exit 99
printf 'nvim-plugins\n' >>"$TEST_CALLS"
case " ${TEST_FAILURES:-} " in *' nvim-plugins '*) exit 1 ;; esac
EOF
cat >"$tmp/scripts/dev/with-github-auth.sh" <<'EOF'
#!/bin/sh
exec "$@"
EOF
cat >"$tmp/bin/nix" <<'EOF'
#!/bin/sh
if [ "$*" = 'flake update' ]; then
  printf 'flake-lock\n' >>"$TEST_CALLS"
  case " ${TEST_FAILURES:-} " in *' flake-lock '*) exit 1 ;; esac
elif [ "$1" = shell ] && [ "$2" = --inputs-from ] && [ "$3" = . ] && [ "$4" = 'nixpkgs#skopeo' ] && [ "$5" = --command ]; then
  shift 5
  exec "$@"
else
  echo "unexpected nix command: $*" >&2
  exit 99
fi
EOF
chmod +x "$tmp/scripts/ci/update-packages.sh" "$tmp/scripts/dev/with-github-auth.sh" "$tmp/scripts/dev/nvim-plugin-pins.sh" "$tmp/bin/nix"
export PATH="$tmp/bin:$PATH" TEST_CALLS="$tmp/calls"
export PACKAGES=must-not-narrow-update-all
printf '%s\n' flake-inputs flake-lock agent-plugins packages t3code nvim-plugins containers fish-plugins >"$tmp/expected"

make -C "$tmp" update-all PACKAGES=also-must-not-narrow >"$tmp/success.out" 2>"$tmp/success.err"
diff -u "$tmp/expected" "$TEST_CALLS"
grep -Fq 'All runtime pins refreshed.' "$tmp/success.out"

for failure in flake-inputs flake-lock agent-plugins packages t3code nvim-plugins containers fish-plugins 'packages containers'; do
  : >"$TEST_CALLS"
  if TEST_FAILURES=$failure make -C "$tmp" update-all >"$tmp/failure.out" 2>"$tmp/failure.err"; then
    echo "update-all passed with a failed stage: $failure" >&2
    exit 1
  fi
  diff -u "$tmp/expected" "$TEST_CALLS"
  grep -Fq 'Update incomplete. Failed targets:' "$tmp/failure.err"
  ! grep -Fq 'All runtime pins refreshed.' "$tmp/failure.out"
done

echo 'update-all orchestration tests passed'
