#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REBUILD_SCRIPT="$SCRIPT_DIR/../nixos-rebuild.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
mkdir -p "$tmpdir/home/nix-config" "$tmpdir/bin"

cat >"$tmpdir/bin/nix" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *lib.hosts*) printf 'nixos' ;;
    *services.nextcloud.extraApps*) printf '%s' "$NIX_TEST_APP_IDS" ;;
    *) echo "unexpected nix invocation: $*" >&2; exit 90 ;;
esac
EOF
cat >"$tmpdir/bin/sudo" <<'EOF'
#!/usr/bin/env bash
if [[ ${NIX_TEST_DUPLICATES:-0} == 1 || ${2:-} == -d ]]; then
    exit 0
fi
exit 1
EOF
cat >"$tmpdir/bin/git" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$tmpdir/bin/alejandra" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"$tmpdir/bin/nh" <<'EOF'
#!/usr/bin/env bash
touch "$NIX_TEST_NH_MARKER"
exit 91
EOF
chmod +x "$tmpdir/bin/"*

run_preflight_failure() {
    local expected_message=$1
    rm -f "$tmpdir/nh-called"
    set +e
    HOME="$tmpdir/home" \
        PATH="$tmpdir/bin:$PATH" \
        NIX_CONFIG_HOST=kim \
        NIX_CONFIG_STATE_DIR="$tmpdir/state" \
        SKIP_ETC_NIXOS_LINK=1 \
        SKIP_SOPS_CHECK=1 \
        NIX_TEST_NH_MARKER="$tmpdir/nh-called" \
        "$REBUILD_SCRIPT" >"$tmpdir/out" 2>"$tmpdir/err"
    status=$?
    set -e

    if [[ $status -eq 0 ]]; then
        echo "rebuild unexpectedly passed Nextcloud ownership preflight" >&2
        exit 1
    fi
    if [[ -e $tmpdir/nh-called ]]; then
        echo "rebuild reached nh after Nextcloud ownership preflight failed" >&2
        exit 1
    fi
    grep -q "$expected_message" "$tmpdir/err"
}

NIX_TEST_APP_IDS=$'calendar\nintegration_paperless' NIX_TEST_DUPLICATES=1 \
    run_preflight_failure 'Nix and store-apps both own'

injection_marker="$tmpdir/injected"
NIX_TEST_APP_IDS=$'calendar\nbad;touch '$injection_marker NIX_TEST_DUPLICATES=0 \
    run_preflight_failure 'Invalid declarative Nextcloud app ID'
if [[ -e $injection_marker ]]; then
    echo "Nextcloud app ID was evaluated as shell syntax" >&2
    exit 1
fi

echo "nixos rebuild Nextcloud preflight tests passed"
