#!/usr/bin/env bash
set -euo pipefail

store_apps_dir=${NEXTCLOUD_STORE_APPS_DIR:-/srv/nextcloud/store-apps}

if [[ -z ${NEXTCLOUD_STORE_APPS_DIR+x} \
    && ${EUID} -ne 0 \
    && ${USER:-} != nextcloud \
    && ${NEXTCLOUD_USE_SUDO:-0} != 1 ]]; then
    echo "Nextcloud app ownership check requires root or the nextcloud service user." >&2
    echo "Try: sudo nextcloud-app-ownership-check" >&2
    exit 2
fi

path_exists() {
    if [[ ${NEXTCLOUD_USE_SUDO:-0} == 1 ]]; then
        sudo test -e "$1" || sudo test -L "$1"
    else
        [[ -e $1 || -L $1 ]]
    fi
}

directory_exists() {
    if [[ ${NEXTCLOUD_USE_SUDO:-0} == 1 ]]; then
        sudo test -d "$1"
    else
        [[ -d $1 ]]
    fi
}

if ! directory_exists "$store_apps_dir"; then
    echo "Nextcloud app ownership check: store-apps directory is absent; nothing to check."
    exit 0
fi

invalid=0
duplicates=()
for app_id in "$@"; do
    case "$app_id" in
        "" | [!A-Za-z0-9]* | *[!A-Za-z0-9_.-]*)
            echo "Invalid declarative Nextcloud app ID: $app_id" >&2
            invalid=1
            continue
            ;;
    esac

    if path_exists "$store_apps_dir/$app_id"; then
        duplicates+=("$app_id")
    fi
done

if ((invalid)); then
    exit 2
fi

if ((${#duplicates[@]} > 0)); then
    printf 'Nextcloud app ownership conflict: Nix and store-apps both own: %s\n' "${duplicates[*]}" >&2
    printf 'Move the mutable copies out of %s before rebuilding.\n' "$store_apps_dir" >&2
    exit 1
fi

printf 'Nextcloud app ownership check passed for %d declarative app(s).\n' "$#"
