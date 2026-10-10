#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
cat > flake.lock <<'EOF'
{"root":"custom-root","nodes":{"custom-root":{"inputs":{"nixpkgs":"nixpkgs","home-manager":"home-manager","llm-agents":"llm-agents","superlocal":"superlocal"}}}}
EOF
selector=$repo_root/scripts/ci/select-flake-inputs.sh
printf '%s\n' home-manager llm-agents nixpkgs > expected
FLAKE_INPUTS='' bash "$selector" > actual
diff -u expected actual
FLAKE_INPUTS=$' \t\n' bash "$selector" > actual
diff -u expected actual
printf '%s\n' llm-agents nixpkgs > expected
FLAKE_INPUTS=$'nixpkgs\tllm-agents\nnixpkgs' bash "$selector" > actual
diff -u expected actual

for invalid in superlocal unknown --override-input 'nixpkgs/something' 'nixpkgs;touch injected' '$(touch injected)' '*'; do
  if FLAKE_INPUTS="nixpkgs $invalid" bash "$selector" > actual 2> error; then
    echo "Invalid selection unexpectedly accepted: $invalid" >&2
    exit 1
  fi
  [[ ! -s actual ]]
  grep -Fq 'Invalid public flake input:' error
done
[[ ! -e injected ]]

for broken in '{}' '{"root":"root","nodes":{"root":{"inputs":{"superlocal":"private"}}}}' 'not json'; do
  printf '%s\n' "$broken" > flake.lock
  if FLAKE_INPUTS='' bash "$selector" > actual 2> error; then
    echo "Broken or empty public input inventory unexpectedly accepted" >&2
    exit 1
  fi
  [[ ! -s actual ]]
done
rm flake.lock
if FLAKE_INPUTS='' bash "$selector" > actual 2> error; then
  echo "Missing lock unexpectedly accepted" >&2
  exit 1
fi
[[ ! -s actual ]]
echo "Public flake input selection tests passed"
