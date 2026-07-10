#!/usr/bin/env bash
# Verify the Neovim config's contract with this flake: every external tool the
# editor shells out to (LSP servers, formatters, linters) must be on PATH —
# i.e. provisioned on the normal Home Manager PATH shared by Neovim, Zed,
# Jujutsu hooks, and interactive shells.
#
# This reads the config's OWN truth (conform's resolved formatter list,
# nvim-lint's linter map, and each lsp/*.lua command). Function-valued LSP
# commands are resolved with vim.lsp.rpc.start temporarily replaced by an argv
# capture function, so no language server is spawned.
#
# Usage: scripts/check-nvim-tooling.sh   (exit 1 if anything is missing)
set -euo pipefail

command -v nvim >/dev/null 2>&1 || {
  echo "nvim not on PATH — skipping editor tooling check" >&2
  exit 0
}

LUA="$(mktemp)"
trap 'rm -f "$LUA"' EXIT

cat >"$LUA" <<'LUA'
require("lazy").load({ plugins = { "conform.nvim", "nvim-lint" } })

-- conform pseudo-formatters that are not external binaries.
local SENTINEL = {
  lsp = true, injected = true, trim_whitespace = true,
  trim_newlines = true, squeeze_blanks = true,
}

local missing, checked = {}, 0
local function want(bin, label)
  if bin == nil or bin == "" then return end
  checked = checked + 1
  if vim.fn.executable(bin) == 0 then
    table.insert(missing, string.format("  %-22s %s", bin, "(" .. label .. ")"))
  end
end

local function missing_metadata(label)
  checked = checked + 1
  table.insert(missing, string.format("  %-22s (%s)", "<metadata required>", label))
end

-- Formatters: resolve each ft's list, including dynamic function-valued
-- entries (the JS/TS prettier/biome selection).
local conform = require("conform")
local seen = {}
for _, spec in pairs(conform.formatters_by_ft or {}) do
  if type(spec) == "function" then spec = spec(0) end
  if type(spec) == "table" then
    for _, name in ipairs(spec) do
      if not seen[name] and not SENTINEL[name] then
        seen[name] = true
        local info = conform.get_formatter_info(name, 0)
        checked = checked + 1
        if not info.available then
          table.insert(missing, string.format("  %-22s (formatter: %s)", info.command or name, name))
        end
      end
    end
  end
end

-- Linters (nvim-lint): the static ft map plus the dynamically-added oxlint.
local lint = require("lint")
local lseen = {}
local function check_linter(name)
  if lseen[name] then return end
  lseen[name] = true
  local l = lint.linters[name]
  local cmd = l and l.cmd
  if type(cmd) == "function" then
    local ok, resolved = pcall(cmd)
    if ok then cmd = resolved end
  end
  if type(cmd) == "table" then cmd = cmd[1] end
  if type(cmd) ~= "string" then cmd = name end
  want(cmd, "linter: " .. name)
end
for _, names in pairs(lint.linters_by_ft or {}) do
  for _, n in ipairs(names) do check_linter(n) end
end
check_linter("oxlint")

-- LSP servers: static commands are read directly. Function commands often
-- start RPC clients and are never invoked here; their executable contract is
-- declared in _tooling.executables beside the function.
for _, f in ipairs(vim.fn.glob(vim.fn.stdpath("config") .. "/lsp/*.lua", false, true)) do
  local ok, cfg = pcall(dofile, f)
  local name = vim.fn.fnamemodify(f, ":t:r")
  if not ok or type(cfg) ~= "table" then
    missing_metadata("LSP config failed to load: " .. name)
  elseif type(cfg.cmd) == "table" then
    want(cfg.cmd[1], "LSP: " .. name)
  elseif type(cfg.cmd) == "string" then
    want(cfg.cmd, "LSP: " .. name)
  elseif type(cfg.cmd) == "function" then
    local captured
    local captured_executable
    local original_start = vim.lsp.rpc.start
    vim.lsp.rpc.start = function(argv)
      captured = argv
      return {}
    end
    local resolved = pcall(cfg.cmd, {}, vim.deepcopy(cfg))
    vim.lsp.rpc.start = original_start

    if resolved and type(captured) == "table" and type(captured[1]) == "string" then
      captured_executable = captured[1]
      want(captured_executable, "LSP: " .. name)
    end

    local executables = cfg._tooling and cfg._tooling.executables
    if type(executables) == "table" then
      for _, executable in ipairs(executables) do
        if executable ~= captured_executable then
          want(executable, "LSP dependency: " .. name)
        end
      end
    elseif not captured_executable then
      missing_metadata("unresolved LSP function cmd: " .. name)
    end
  end
end

if #missing > 0 then
  io.stderr:write(string.format("\nMissing editor tools (%d of %d checked):\n", #missing, checked))
  io.stderr:write(table.concat(missing, "\n") .. "\n")
  io.stderr:write("\nAdd executables to users/maxpw/modules/packages/dev-tools.nix (normal PATH) and rebuild.\n")
  io.stderr:write("Uncapturable function-valued LSP commands must declare _tooling.executables.\n")
  vim.cmd("1cquit")
else
  print(string.format("OK: all %d editor tools resolve on PATH.", checked))
  vim.cmd("qa")
end
LUA

exec nvim --headless -c "luafile $LUA"
