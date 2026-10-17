# shellcheck shell=bash

run_sops_key_check() {
    if [[ "${SOPS_KEY_USE_SUDO:-0}" == "1" ]]; then
        sudo "$@"
    else
        "$@"
    fi
}

sops_key_metadata() {
    local path="$1"
    if run_sops_key_check stat -c '%u:%g:%a' "$path" 2>/dev/null; then
        return 0
    fi
    run_sops_key_check stat -f '%u:%g:%Lp' "$path" 2>/dev/null
}

# Validate the file itself, not merely its parent directory. Refuse symlinks,
# unexpected ownership, or group/world permissions.
validate_sops_key() {
    local path="$1"
    local expected_uid="$2"
    local expected_gid="$3"
    local metadata

    run_sops_key_check test -f "$path" || return 1
    if run_sops_key_check test -L "$path"; then
        return 1
    fi
    run_sops_key_check test -r "$path" || return 1
    metadata=$(sops_key_metadata "$path") || return 1
    [[ "$metadata" == "$expected_uid:$expected_gid:600" ]]
}
