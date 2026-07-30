#!/usr/bin/env bash
set -euo pipefail

store_apps_dir=${NEXTCLOUD_STORE_APPS_DIR:-/srv/nextcloud/store-apps}
ownership_check=${NEXTCLOUD_OWNERSHIP_CHECK_BIN:-$(dirname "${BASH_SOURCE[0]}")/check-nextcloud-app-ownership.sh}
occ_bin=${NEXTCLOUD_OCC_BIN:-nextcloud-occ}
find_bin=${NEXTCLOUD_FIND_BIN:-find}

"$ownership_check" "$@"

if [[ ! -d $store_apps_dir ]]; then
    echo "No mutable Nextcloud store-apps directory to update."
    exit 0
fi

scan_file=$(mktemp)
trap 'rm -f "$scan_file"' EXIT
if ! "$find_bin" "$store_apps_dir" -mindepth 1 -maxdepth 1 -type d -print0 \
    | sort --zero-terminated >"$scan_file"; then
    echo "Failed to enumerate mutable Nextcloud store apps." >&2
    exit 1
fi

mutable_apps=()
invalid_apps=()
while IFS= read -r -d "" app_dir; do
    [[ -f $app_dir/appinfo/info.xml ]] || continue
    app_id=${app_dir##*/}
    case "$app_id" in
        "" | [!A-Za-z0-9]* | *[!A-Za-z0-9_.-]*)
            invalid_apps+=("$app_id")
            ;;
        *)
            mutable_apps+=("$app_id")
            ;;
    esac
done <"$scan_file"

if ((${#invalid_apps[@]} > 0)); then
    printf 'Refusing invalid mutable Nextcloud app ID(s): %s\n' "${invalid_apps[*]}" >&2
    exit 2
fi

if ((${#mutable_apps[@]} == 0)); then
    echo "No mutable Nextcloud store apps to update."
    exit 0
fi

failed_apps=()
for app_id in "${mutable_apps[@]}"; do
    echo "Updating mutable Nextcloud app: $app_id"
    if ! "$occ_bin" app:update -- "$app_id"; then
        failed_apps+=("$app_id")
    fi
done

if ((${#failed_apps[@]} > 0)); then
    printf 'Failed to update mutable Nextcloud app(s): %s\n' "${failed_apps[*]}" >&2
    exit 1
fi
