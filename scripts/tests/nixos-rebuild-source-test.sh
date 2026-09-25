#!/usr/bin/env bash
# The rebuild deploys a .gitignore-aware snapshot, never rewrites the
# checkout, keeps its log outside the checkout, and removes the snapshot.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
config="$tmp/home/nix-config"
mkdir -p "$tmp/bin" "$config/scripts/lib"
cp "$repo_root/scripts/nixos-rebuild.sh" "$config/scripts/"
cp "$repo_root/scripts/lib/host-detect.sh" "$repo_root/scripts/lib/rebuild-state.sh" "$config/scripts/lib/"
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
echo "build output"
EOF
chmod +x "$tmp/bin/"*

HOME="$tmp/home" PATH="$tmp/bin:$PATH" NIX_CONFIG_HOST=joyce \
    NIX_CONFIG_STATE_DIR="$tmp/state" TEST_SNAPSHOT="$tmp/snapshot" \
    bash "$config/scripts/nixos-rebuild.sh" > "$tmp/out" 2> "$tmp/err" || {
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

echo "nixos rebuild source tests passed"
