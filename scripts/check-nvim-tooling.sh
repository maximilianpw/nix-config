#!/usr/bin/env bash
# Verify the Neovim config's contract with this flake: every external tool the
# editor shells out to (LSP servers, formatters, linters) must be on PATH —
# i.e. provisioned by users/maxpw/modules/neovim.nix (or home.packages).
#
# This reads the config's OWN truth (conform's resolved formatter list,
# nvim-lint's linter map, and the cmd[1] of each lsp/*.lua), so it tracks new
# tools automatically instead of duplicating a hand-maintained list.
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
  if type(cmd) ~= "string" then cmd = name end -- function cmd: fall back to the name
  want(cmd, "linter: " .. name)
end
for _, names in pairs(lint.linters_by_ft or {}) do
  for _, n in ipairs(names) do check_linter(n) end
end
check_linter("oxlint")

-- LSP servers: the cmd[1] of each enabled lsp/*.lua config.
for _, f in ipairs(vim.fn.glob(vim.fn.stdpath("config") .. "/lsp/*.lua", false, true)) do
  local ok, cfg = pcall(dofile, f)
  if ok and type(cfg) == "table" and type(cfg.cmd) == "table" then
    want(cfg.cmd[1], "LSP: " .. vim.fn.fnamemodify(f, ":t:r"))
  end
end

if #missing > 0 then
  io.stderr:write(string.format("\nMissing editor tools (%d of %d checked):\n", #missing, checked))
  io.stderr:write(table.concat(missing, "\n") .. "\n")
  io.stderr:write("\nAdd them to users/maxpw/modules/neovim.nix and rebuild.\n")
  vim.cmd("1cquit")
else
  print(string.format("OK: all %d editor tools resolve on PATH.", checked))
  vim.cmd("qa")
end
LUA

exec nvim --headless -c "luafile $LUA"
