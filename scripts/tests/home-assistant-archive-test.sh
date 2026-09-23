#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
script="$repo_root/scripts/home-assistant-archive.sh"
# shellcheck source=scripts/tests/portable-gnu-fixtures.sh
source "$repo_root/scripts/tests/portable-gnu-fixtures.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

install_portable_gnu_tar_fixture "$tmp/tar"
cat > "$tmp/tar-fail" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$tmp/tar-fail"
mkdir -p "$tmp/lib/hass"
printf 'config\n' > "$tmp/lib/hass/configuration.yaml"

export TEST_REAL_TAR_BIN
TEST_REAL_TAR_BIN=$(command -v tar)
export HOME_ASSISTANT_SOURCE_DIR=$tmp/lib/hass
export HOME_ASSISTANT_ARCHIVE=$tmp/archive/config.tar

# The archive holds the tree under its own directory name and is private.
TAR_BIN=$tmp/tar bash "$script"
"$TEST_REAL_TAR_BIN" -tf "$HOME_ASSISTANT_ARCHIVE" | grep -Fxq 'hass/configuration.yaml'
[[ $(stat -c %a "$HOME_ASSISTANT_ARCHIVE" 2>/dev/null || stat -f %Lp "$HOME_ASSISTANT_ARCHIVE") == 600 ]]

# A failed archive leaves the previous one in place and fails the step.
if TAR_BIN=$tmp/tar-fail bash "$script"; then
  echo "a failed archive unexpectedly succeeded" >&2
  exit 1
fi
"$TEST_REAL_TAR_BIN" -tf "$HOME_ASSISTANT_ARCHIVE" | grep -Fxq 'hass/configuration.yaml'

echo "home assistant archive tests passed"
