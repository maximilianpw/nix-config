#!/usr/bin/env bash
# Behavioral checks for the Nixvim editor packages, run by the
# `nvim-candidate` flake check. Everything happens under a disposable HOME; the
# old chezmoi/lazy.nvim locations are seeded with files that fail if loaded.
set -euo pipefail

: "${NVIM_TERMINAL:?NVIM_TERMINAL must be set}"
: "${NVIM_VSCODE:?NVIM_VSCODE must be set}"
: "${NVIM_PLAIN:?NVIM_PLAIN must be set}"
: "${NVIM_CONFIG_SOURCE:?NVIM_CONFIG_SOURCE must be set}"
: "${NVIM_TESTS:?NVIM_TESTS must be set}"

work="$(mktemp -d "${TMPDIR:-/tmp}/nvim-candidate-test.XXXXXX")"
trap 'rm -rf "$work"' EXIT

export HOME="$work/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export NVIM_CONFIG_TEST_ROOT="$NVIM_CONFIG_SOURCE"
export NVIM_LOG_FILE="$work/nvim.log"
unset NVIM NVIM_APPNAME VIMINIT MYVIMRC
mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME" "$XDG_CACHE_HOME"

poison() {
  mkdir -p "$(dirname "$1")"
  printf '%s\n' 'error("loaded legacy runtime file: " .. debug.getinfo(1, "S").source)' >"$1"
}
for app in nvim nvim-candidate nvim-vscode-candidate; do
  poison "$XDG_CONFIG_HOME/$app/init.lua"
  poison "$XDG_CONFIG_HOME/$app/plugin/legacy.lua"
  poison "$XDG_CONFIG_HOME/$app/lsp/gopls.lua"
  poison "$XDG_CONFIG_HOME/$app/lua/config/init.lua"
  poison "$XDG_DATA_HOME/$app/site/plugin/legacy.lua"
done

failed=0
pass() { printf 'ok   %s\n' "$1"; }
fail() {
  printf 'FAIL %s\n%s\n' "$1" "${2:-}"
  failed=1
}
check() {
  local name="$1" output
  shift
  if output="$("$@" 2>&1)"; then
    pass "$name"
  else
    fail "$name" "$output"
  fi
}
# Run a Lua test file inside an editor package; any error fails the process.
in_editor() {
  local nvim="$1" file="$2"
  shift 2
  "$nvim" --headless "$@" \
    -c "lua local ok, err = pcall(dofile, [[$file]]); if not ok then io.stderr:write(tostring(err) .. '\n'); vim.cmd('cquit') end" \
    -c 'qa!'
}

echo "--- Lua syntax ---"
syntax="$work/syntax.lua"
cat >"$syntax" <<'EOF'
local failures = {}
for _, dir in ipairs({ vim.env.NVIM_CONFIG_SOURCE, vim.env.NVIM_TESTS }) do
  for _, file in ipairs(vim.fn.globpath(dir, "**/*.lua", true, true)) do
    local ok, err = loadfile(file)
    if not ok then
      failures[#failures + 1] = err
    end
  end
end
assert(#failures == 0, table.concat(failures, "\n"))
EOF
check "all Lua files parse" "$NVIM_PLAIN" --clean -l "$syntax"

echo "--- Config contracts (no plugins) ---"
for suite in architecture bigfile formatting project-tools source registry; do
  check "$suite" "$NVIM_PLAIN" --clean -l "$NVIM_TESTS/$suite.lua"
done

echo "--- LSP registration drift ---"
enable_list="$(sed -n '/local servers = {/,/^      }/p' "$NVIM_CONFIG_SOURCE/lua/plugins/lsp/init.lua" | grep -o '"[a-z_]*"' | tr -d '"')"
for file in "$NVIM_CONFIG_SOURCE"/lsp/*.lua; do
  name="$(basename "$file" .lua)"
  if ! grep -qx "$name" <<<"$enable_list"; then
    fail "lsp/$name.lua exists but '$name' is not in the vim.lsp.enable list"
  elif ! grep -q "\`$name\`" "$NVIM_CONFIG_SOURCE/NIXOS_SETUP.md"; then
    fail "'$name' enabled but not documented in NIXOS_SETUP.md"
  fi
done
for name in $enable_list; do
  [[ -f "$NVIM_CONFIG_SOURCE/lsp/$name.lua" ]] || fail "'$name' is enabled but lsp/$name.lua does not exist"
done
pass "lsp/ files, enable list, and NIXOS_SETUP.md agree"

echo "--- Terminal package ---"
if output="$("$NVIM_TERMINAL" --headless -c 'lua print("init ok")' -c 'qa' 2>&1)" && grep -q "init ok" <<<"$output"; then
  pass "startup"
else
  fail "startup" "$output"
fi

messages="$("$NVIM_TERMINAL" --headless -c 'lua vim.wait(200)' -c 'redir @a | silent messages | redir END | lua print(vim.fn.getreg("a"))' -c 'qa' 2>&1 || true)"
if grep -qiE 'error|E[0-9]{3,4}:' <<<"$messages"; then
  fail "startup messages contain errors" "$messages"
else
  pass "no startup errors"
fi

printf '%s\n' 'export default function App(){ return <div /> }' >"$work/probe.tsx"
printf '%s\n' 'const el = <div />' >"$work/probe.jsx"
for probe in "$work/probe.tsx" "$work/probe.jsx"; do
  output="$("$NVIM_TERMINAL" --headless "$probe" \
    -c 'lua local b=vim.api.nvim_get_current_buf(); print(vim.treesitter.highlighter.active[b] ~= nil and "active" or "inactive")' \
    -c 'qa' 2>&1)"
  if grep -qx "active" <<<"$output"; then
    pass "treesitter highlighting ${probe##*.}"
  else
    fail "treesitter highlighting ${probe##*.}" "$output"
  fi
done

check "package integrity" in_editor "$NVIM_TERMINAL" "$NVIM_TESTS/integrity.lua"
check "completion provider contracts" in_editor "$NVIM_TERMINAL" "$NVIM_TESTS/completion.lua"
check "plugin contracts" in_editor "$NVIM_TERMINAL" "$NVIM_TESTS/plugins.lua"
check "dashboard without lazy.nvim" in_editor "$NVIM_TERMINAL" "$NVIM_TESTS/dashboard.lua"

echo "--- VS Code package ---"
# Stand-in for the vscode-neovim extension runtime, bootstrapped like the real one.
runtime="$work/vscode-neovim/runtime"
mkdir -p "$runtime/lua/vscode"
cat >"$runtime/vscode-neovim.vim" <<'EOF'
let g:vscode = 1
let g:vscode_neovim_runtime = fnamemodify(resolve(expand('<sfile>:p')), ':h')
lua vim.opt.rtp:prepend(vim.g.vscode_neovim_runtime)
EOF
cat >"$runtime/lua/vscode.lua" <<'EOF'
_G.vscode_test_actions = {}
return {
  action = function(name)
    table.insert(_G.vscode_test_actions, name)
  end,
}
EOF
printf '%s\n' 'return { from_extension_runtime = true }' >"$runtime/lua/vscode/internal.lua"
check "VS Code package boundary" in_editor "$NVIM_VSCODE" "$NVIM_TESTS/vscode-plugins.lua" \
  --cmd "execute 'source' fnameescape('$runtime/vscode-neovim.vim')"

echo "--- Startup time (informational) ---"
"$NVIM_TERMINAL" --headless --startuptime "$work/startup.log" -c 'qa' >/dev/null 2>&1 || true
awk '/NVIM STARTED/ { print "terminal package: " $1 " ms until NVIM STARTED (headless)" }' "$work/startup.log"

if [[ $failed -ne 0 ]]; then
  echo "Some checks failed."
  exit 1
fi
echo "All checks passed."
