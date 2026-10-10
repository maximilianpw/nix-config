-- Key ownership, run inside the terminal package by tests/run.sh after every
-- offline plugin hook has loaded: a new plugin must not silently take over a
-- key that Neovim or another plugin already owns.
local registry = require("config.plugins")

-- Neovim defaults that no plugin may replace, compared against a --clean
-- editor of the same version so the list follows the editor (0.13 adds al/il).
local native = {
  { "n", "gx" },
  { "x", "gx" },
  { "n", "gra" },
  { "x", "gra" },
  { "n", "gri" },
  { "n", "grn" },
  { "n", "grr" },
  { "n", "grt" },
  { "x", "an" },
  { "x", "in" },
  { "o", "an" },
  { "o", "in" },
  { "x", "al" },
  { "x", "il" },
  { "o", "al" },
  { "o", "il" },
  { "n", "Q" },
}

local function describe(mode, lhs)
  local map = vim.fn.maparg(lhs, mode, false, true)
  return map.lhs and (map.desc or map.rhs or "<callback>") or vim.NIL
end

local query = { "local out = {}" }
for _, key in ipairs(native) do
  query[#query + 1] = string.format(
    "local m = vim.fn.maparg(%q, %q, false, true); out[#out + 1] = m.lhs and (m.desc or m.rhs or '<callback>') or vim.NIL",
    key[2],
    key[1]
  )
end
query[#query + 1] = "io.stdout:write(vim.json.encode(out))"
local clean = vim
  .system({ assert(vim.env.NVIM_PLAIN), "--clean", "--headless", "-c", "lua " .. table.concat(query, "; "), "-c", "qa!" })
  :wait()
assert(clean.code == 0, "could not read Neovim's default mappings: " .. clean.stderr)
local defaults = vim.json.decode(clean.stdout)

local names = {}
for _, spec in ipairs(registry.specs(false)) do
  for _, s in ipairs(type(spec[1]) == "table" and spec or { spec }) do
    if s[1] ~= "supermaven-nvim" and s[1] ~= "amp.nvim" then
      names[#names + 1] = s[1]
    end
  end
end
require("lz.n").trigger_load(names)
-- Blink registers its InsertEnter hook only after its asynchronous setup, then
-- installs its keys buffer-locally.
vim.wait(2000, function()
  vim.api.nvim_exec_autocmds("InsertEnter", { buffer = 0 })
  return vim.startswith(vim.fn.maparg("<Tab>", "i", false, true).desc or "", "blink.cmp")
end, 50)

local failures = {}
for i, key in ipairs(native) do
  local got = describe(key[1], key[2])
  if got ~= defaults[i] then
    failures[#failures + 1] = string.format(
      "%s %s: expected Neovim default %s, got %s",
      key[1],
      key[2],
      vim.inspect(defaults[i]),
      vim.inspect(got)
    )
  end
end

-- Keys with a chosen owner, identified by the description that owner sets.
local owned = {
  { "n", "-", "Open Parent Directory (oil)" },
  -- vim-tmux-navigator's own plugin file remaps it without a description.
  { "n", "<C-l>", ":<C-U>TmuxNavigateRight<cr>" },
  { "n", "cx", "Exchange" },
  { "n", "cr", "Replace" },
  { "n", "]t", "Next TODO Comment" },
  { "n", "<leader>xx", "Workspace Diagnostics" },
  { "n", "<leader>gd", "Diff Repository (CodeDiff)" },
  { "i", "<Esc>", "Escape and end snippet" },
  { "s", "<Esc>", "Escape and end snippet" },
  -- Blink lists the chain in order, so this also pins Tab's priority.
  { "i", "<Tab>", "blink.cmp: Snippet Forward, <Custom Fn>" },
  { "i", "<CR>", "blink.cmp: Accept" },
  { "i", "<C-y>", "blink.cmp: Select And Accept" },
}
if vim.fn.has("nvim-0.13") == 1 then
  owned[#owned + 1] = { "n", "<C-q>", "Clear multicursors" }
end
for _, key in ipairs(owned) do
  local got = describe(key[1], key[2])
  if got ~= key[3] then
    failures[#failures + 1] = string.format("%s %s: expected %q, got %s", key[1], key[2], key[3], vim.inspect(got))
  end
end

assert(#failures == 0, "key ownership changed:\n" .. table.concat(failures, "\n"))
print("key ownership passed")
