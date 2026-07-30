#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECK_SCRIPT="$SCRIPT_DIR/../check-nextcloud-app-ownership.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
store_apps="$tmpdir/store-apps"
mkdir -p "$store_apps" "$tmpdir/bin"
cat >"$tmpdir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
chmod +x "$tmpdir/bin/sudo"

NEXTCLOUD_STORE_APPS_DIR="$store_apps" "$CHECK_SCRIPT" calendar integration_paperless >/dev/null
PATH="$tmpdir/bin:$PATH" NEXTCLOUD_USE_SUDO=1 NEXTCLOUD_STORE_APPS_DIR="$store_apps" \
    "$CHECK_SCRIPT" calendar integration_paperless >/dev/null

mkdir "$store_apps/calendar"
if NEXTCLOUD_STORE_APPS_DIR="$store_apps" "$CHECK_SCRIPT" calendar integration_paperless >"$tmpdir/out" 2>"$tmpdir/err"; then
    echo "ownership check unexpectedly accepted duplicate Calendar app" >&2
    exit 1
fi
grep -q 'Nix and store-apps both own: calendar' "$tmpdir/err"

rm -rf "$store_apps/calendar"
ln -s /missing "$store_apps/integration_paperless"
if NEXTCLOUD_STORE_APPS_DIR="$store_apps" "$CHECK_SCRIPT" calendar integration_paperless >"$tmpdir/out" 2>"$tmpdir/err"; then
    echo "ownership check unexpectedly accepted a dangling duplicate symlink" >&2
    exit 1
fi
grep -q 'Nix and store-apps both own: integration_paperless' "$tmpdir/err"

set +e
NEXTCLOUD_STORE_APPS_DIR="$store_apps" "$CHECK_SCRIPT" 'bad/app' >"$tmpdir/out" 2>"$tmpdir/err"
status=$?
set -e
if [[ $status -ne 2 ]]; then
    echo "invalid app ID returned $status instead of 2" >&2
    exit 1
fi
grep -q 'Invalid declarative Nextcloud app ID' "$tmpdir/err"

echo "nextcloud app ownership tests passed"
