-- Package integrity for the terminal editor: no legacy runtime paths, every
-- registered plugin is packaged once, every plugin hook runs, native libraries
-- and Treesitter grammars come from Nix, and nothing is installed at runtime.
local registry = require("config.plugins")
local home = assert(vim.env.HOME)

local errors = {}
local notify = vim.notify
vim.notify = function(msg, level, ...)
  if level and level >= vim.log.levels.ERROR then
    errors[#errors + 1] = msg
  end
  return notify(msg, level, ...)
end

assert(vim.g.maxpw_nvim_profile == "terminal", "not running the terminal package")
local app = vim.env.NVIM_APPNAME or "nvim"
assert(vim.fs.basename(vim.fn.stdpath("data")) == app, "stdpath state does not match NVIM_APPNAME " .. app)

-- Only store paths (plus nvim-treesitter's manual-install escape hatch) may be on the runtimepath.
for _, dir in ipairs(vim.api.nvim_list_runtime_paths()) do
  local allowed = vim.startswith(dir, "/nix/store/") or dir:find("treesitter-manual-installs", 1, true)
  assert(allowed, "impure runtimepath entry: " .. dir)
end
assert(#vim.api.nvim_get_runtime_file("plugin/legacy.lua", true) == 0, "legacy plugin directory is on the runtimepath")
for _, file in ipairs(vim.api.nvim_get_runtime_file("lsp/gopls.lua", true)) do
  assert(vim.startswith(file, "/nix/store/"), "legacy lsp/ config discovered: " .. file)
end

-- Every spec the terminal profile registers resolves to exactly one packaged plugin.
local names = {}
for _, spec in ipairs(registry.specs(false)) do
  local list = type(spec[1]) == "table" and spec or { spec }
  for _, s in ipairs(list) do
    local dirs = vim.fn.globpath(vim.o.packpath, "pack/*/*/" .. s[1], false, true)
    assert(#dirs == 1, s[1] .. " is packaged " .. #dirs .. " times")
    names[#names + 1] = s[1]
  end
end

-- Run every after-hook. The Supermaven engine and Amp's IDE server are network
-- services; they are excluded from this offline check and verified interactively.
local online = { ["supermaven-nvim"] = true, ["amp.nvim"] = true }
vim.fn.mkdir(vim.fs.joinpath(home, "Documents", "obsidian vault"), "p")
require("lz.n").trigger_load(vim.tbl_filter(function(name)
  return not online[name]
end, names))
vim.wait(200)
assert(#errors == 0, "plugin hooks reported errors:\n" .. table.concat(errors, "\n"))

-- Native components must be the Nix-built ones.
local fuzzy = require("blink.cmp.fuzzy")
assert(fuzzy.implementation_type == "rust", "blink.cmp is not using its Rust matcher: " .. tostring(fuzzy.implementation_type))
local ok_fff, fff_rust = pcall(require, "fff.rust")
assert(ok_fff and type(fff_rust) == "table", "fff.nvim native library failed to load: " .. tostring(fff_rust))

for _, lang in ipairs(vim.g.maxpw_treesitter_parsers) do
  assert(vim.treesitter.language.add(lang), "missing Treesitter parser: " .. lang)
  for _, parser in ipairs(vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", true)) do
    assert(vim.startswith(parser, "/nix/store/"), "non-Nix parser for " .. lang .. ": " .. parser)
  end
end
for _, lang in ipairs({ "javascript", "tsx", "typescript", "lua", "markdown" }) do
  assert(vim.treesitter.query.get(lang, "highlights"), "missing highlight queries: " .. lang)
end

-- Nothing may have been fetched or compiled into writable locations.
for _, path in ipairs({
  vim.fs.joinpath(home, ".supermaven"),
  vim.fs.joinpath(vim.fn.stdpath("data"), "lazy"),
  vim.fs.joinpath(vim.fn.stdpath("data"), "site", "parser"),
  vim.fs.joinpath(vim.fn.stdpath("cache"), "treesitter-manual-installs", "parser"),
}) do
  assert(not vim.uv.fs_stat(path), "runtime install detected: " .. path)
end

print("terminal package integrity passed (" .. #names .. " plugins)")
