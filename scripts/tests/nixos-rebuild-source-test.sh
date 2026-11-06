#!/usr/bin/env bash
# The rebuild deploys a .gitignore-aware snapshot, never rewrites the
# checkout, keeps its log outside the checkout, and removes the snapshot.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
config="$tmp/home/nix-config"
mkdir -p "$tmp/bin" "$config/scripts/rebuild/lib"
cp "$repo_root/scripts/rebuild/nixos-rebuild.sh" "$config/scripts/rebuild/"
cp "$repo_root/scripts/rebuild/lib/host-detect.sh" "$repo_root/scripts/rebuild/lib/rebuild-state.sh" \
    "$repo_root/scripts/rebuild/lib/rebuild-log.sh" "$config/scripts/rebuild/lib/"
printf '.artifacts/\n' > "$config/.gitignore"
printf '{ }\n' > "$config/flake.nix"
git -C "$config" init -q
git -C "$config" add .
git -C "$config" -c user.name=test -c user.email=test@example.invalid commit -qm init
printf '{ }\n' > "$config/new-module.nix"
mkdir -p "$config/.artifacts"
printf 'scratch\n' > "$config/.artifacts/image.wsl"
export TEST_COMMANDS=$tmp/commands

cat > "$tmp/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf 'Darwin\n'
EOF
cat > "$tmp/bin/nix" <<'EOF'
#!/usr/bin/env bash
[[ $1 == eval ]] || exit 90
printf 'darwin'
EOF
cat > "$tmp/bin/alejandra" <<'EOF'
#!/usr/bin/env bash
printf 'alejandra %s\n' "$*" >> "$TEST_COMMANDS"
EOF
cat > "$tmp/bin/nh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'nh %s\n' "$1" >> "$TEST_COMMANDS"
[[ $1 == darwin ]] || exit 0
source_dir=${!#}
source_dir=${source_dir#path:}
printf '%s\n' "$source_dir" > "$TEST_SNAPSHOT"
[[ -f $source_dir/new-module.nix ]] || { echo "untracked module missing" >&2; exit 1; }
[[ ! -e $source_dir/.artifacts ]] || { echo "ignored artifacts copied" >&2; exit 1; }
[[ ! -e $source_dir/.git ]] || { echo ".git copied" >&2; exit 1; }
if [[ ${TEST_NH_FAIL:-0} == 1 ]]; then
    printf '\033[?25l\033[1m\xe2\x8f\xb1 0s\033[0m\033[1G\033[2K\033[1m\xe2\x8f\xb1 1s\033[0m\033[1G\033[2Kbuilding foo\n'
    printf '\033[0m\xe2\x94\x8f\xe2\x94\x81 Dependency Graph:\n\xe2\x94\x97\xe2\x94\x81 \xe2\x88\x91 1s\033[2K\033[1F\033[2K'
    printf "\033[31;1merror:\033[0m Cannot build '/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo.drv'.\n"
    printf '       Reason: builder failed with exit code 3.\n'
    printf '\xe2\x94\x83 \033[31;1merror:\033[0m repeated in the nom error box\n'
    printf 'Error: nh trailer\n'
    exit 1
fi
echo "build output"
EOF
chmod +x "$tmp/bin/"*

HOME="$tmp/home" PATH="$tmp/bin:$PATH" NIX_CONFIG_HOST=joyce \
    NIX_CONFIG_STATE_DIR="$tmp/state" TEST_SNAPSHOT="$tmp/snapshot" \
    bash "$config/scripts/rebuild/nixos-rebuild.sh" > "$tmp/out" 2> "$tmp/err" || {
    cat "$tmp/out" "$tmp/err" >&2
    exit 1
}

grep -Fq 'alejandra --check --quiet .' "$TEST_COMMANDS"
grep -Fxq 'nh clean' "$TEST_COMMANDS"
grep -Fq '+ new-module.nix' "$tmp/out"
grep -Fxq 'build output' "$tmp/state/rebuild.log"
[[ ! -e $config/nixos-switch.log ]]
[[ ! -e $(cat "$tmp/snapshot") ]]
[[ -z $(git -C "$config" status --porcelain --untracked-files=no) ]]


if HOME="$tmp/home" PATH="$tmp/bin:$PATH" NIX_CONFIG_HOST=joyce TEST_NH_FAIL=1 \
    NIX_CONFIG_STATE_DIR="$tmp/state" TEST_SNAPSHOT="$tmp/snapshot" \
    bash "$config/scripts/rebuild/nixos-rebuild.sh" > "$tmp/out" 2> "$tmp/err"; then
    echo "rebuild unexpectedly succeeded after nh failed" >&2
    exit 1
fi
refute() {
    if "$@"; then
        echo "unexpectedly true: $*" >&2
        exit 1
    fi
}
summary=$(sed -n '/Rebuild failed:/,$p' "$tmp/out")
grep -Fxq "error: Cannot build '/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-foo.drv'." <<< "$summary"
grep -Fxq '       Reason: builder failed with exit code 3.' <<< "$summary"
refute grep -Fq 'nh trailer' <<< "$summary"
log=$tmp/state/rebuild.log
grep -Fxq 'building foo' "$log"
grep -Fxq 'Error: nh trailer' "$log"
refute grep -q $'\033' "$log"
refute grep -Eq '^(⏱|┏|┃|┗)' "$log"
[[ ! -e $log.tmp ]]

echo "nixos rebuild source tests passed"
