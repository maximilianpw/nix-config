#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
UPDATE_SCRIPT="$SCRIPT_DIR/../update-nextcloud-store-apps.sh"
CHECK_SCRIPT="$SCRIPT_DIR/../check-nextcloud-app-ownership.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
store_apps="$tmpdir/store-apps"
mkdir -p "$store_apps/notes/appinfo" "$store_apps/bookmarks/appinfo" "$store_apps/incomplete"
touch "$store_apps/notes/appinfo/info.xml" "$store_apps/bookmarks/appinfo/info.xml"

cat >"$tmpdir/occ" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$NEXTCLOUD_OCC_LOG"
if [[ ${3:-} == "${NEXTCLOUD_OCC_FAIL_APP:-}" ]]; then
    exit 1
fi
EOF
chmod +x "$tmpdir/occ"

run_updater() {
    NEXTCLOUD_STORE_APPS_DIR="$store_apps" \
        NEXTCLOUD_OWNERSHIP_CHECK_BIN="$CHECK_SCRIPT" \
        NEXTCLOUD_OCC_BIN="$tmpdir/occ" \
        NEXTCLOUD_OCC_LOG="$tmpdir/occ.log" \
        "$UPDATE_SCRIPT" calendar integration_paperless
}

run_updater >/dev/null
cat >"$tmpdir/expected" <<'EOF'
app:update -- bookmarks
app:update -- notes
EOF
cmp "$tmpdir/expected" "$tmpdir/occ.log"

mkdir "$store_apps/calendar"
if run_updater >"$tmpdir/out" 2>"$tmpdir/err"; then
    echo "store app updater unexpectedly accepted duplicate Calendar ownership" >&2
    exit 1
fi
grep -q 'Nix and store-apps both own: calendar' "$tmpdir/err"
if [[ $(wc -l <"$tmpdir/occ.log") -ne 2 ]]; then
    echo "store app updater changed apps after ownership check failed" >&2
    exit 1
fi
rmdir "$store_apps/calendar"

mkdir -p "$store_apps/--all/appinfo"
touch "$store_apps/--all/appinfo/info.xml"
if run_updater >"$tmpdir/out" 2>"$tmpdir/err"; then
    echo "store app updater unexpectedly accepted --all as an app ID" >&2
    exit 1
fi
grep -q 'Refusing invalid mutable Nextcloud app ID(s): --all' "$tmpdir/err"
if [[ $(wc -l <"$tmpdir/occ.log") -ne 2 ]]; then
    echo "store app updater ran OCC after finding an invalid app ID" >&2
    exit 1
fi
rm -r "$store_apps/--all"

: >"$tmpdir/occ.log"
if NEXTCLOUD_OCC_FAIL_APP=bookmarks run_updater >"$tmpdir/out" 2>"$tmpdir/err"; then
    echo "store app updater hid an OCC update failure" >&2
    exit 1
fi
cmp "$tmpdir/expected" "$tmpdir/occ.log"
grep -q 'Failed to update mutable Nextcloud app(s): bookmarks' "$tmpdir/err"

cat >"$tmpdir/find-fails" <<'EOF'
#!/usr/bin/env bash
exit 9
EOF
chmod +x "$tmpdir/find-fails"
: >"$tmpdir/occ.log"
if NEXTCLOUD_FIND_BIN="$tmpdir/find-fails" run_updater >"$tmpdir/out" 2>"$tmpdir/err"; then
    echo "store app updater hid app discovery failure" >&2
    exit 1
fi
grep -q 'Failed to enumerate mutable Nextcloud store apps' "$tmpdir/err"
if [[ -s $tmpdir/occ.log ]]; then
    echo "store app updater ran OCC after app discovery failed" >&2
    exit 1
fi

echo "nextcloud store app updater tests passed"
