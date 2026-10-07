local root = assert(vim.env.NVIM_CONFIG_TEST_ROOT)
vim.opt.runtimepath:prepend(root)
require("config.bigfile")

local buf = vim.api.nvim_get_current_buf()
vim.wo.cursorline = true
vim.wo.relativenumber = true
vim.wo.scrolloff = 9
vim.wo.foldmethod = "expr"
vim.bo.indentexpr = "0"
vim.bo.syntax = "lua"
local first = vim.api.nvim_get_current_win()
vim.cmd.vsplit()
local second = vim.api.nvim_get_current_win()
vim.wo.scrolloff = 7

local function change(size, event)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { string.rep("x", size) })
  vim.api.nvim_exec_autocmds(event or "TextChanged", { buffer = buf })
end

change(vim.g.bigfile.huge + 1)
assert(vim.b.bigfile_level == "huge", "unsaved growth did not reclassify")
assert(vim.bo.syntax == "off" and vim.bo.indentexpr == "", "expensive buffer options remain enabled")
assert(not vim.lsp.semantic_tokens.is_enabled({ bufnr = buf }), "semantic tokens remain enabled")
for _, win in ipairs({ first, second }) do
  assert(not vim.wo[win].cursorline and not vim.wo[win].relativenumber, "window UI policy missing")
  assert(vim.wo[win].scrolloff == 3 and vim.wo[win].foldmethod == "manual", "window folding policy missing")
end

-- An unrelated small buffer must not inherit large-file window settings.
vim.cmd.enew()
assert(not _G.is_bigfile(), "large-file flags leaked to another buffer")
assert(vim.wo.cursorline and vim.wo.scrolloff ~= 3, "window policy leaked across buffers")
vim.api.nvim_win_set_buf(second, buf)
vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = buf })
assert(vim.wo.scrolloff == 3, "returning to large buffer did not reapply policy")

change(20, "TextChangedI")
assert(not _G.is_bigfile(), "shrinking edits retained large-file flags")
assert(vim.bo.syntax == "lua" and vim.bo.indentexpr == "0", "buffer options were not restored")
assert(vim.lsp.semantic_tokens.is_enabled({ bufnr = buf }), "semantic tokens did not recover")
for _, win in ipairs({ first, second }) do
  assert(vim.wo[win].cursorline and vim.wo[win].relativenumber, "window UI did not recover")
  assert(vim.wo[win].foldmethod == "expr", "foldmethod did not recover")
end
assert(vim.wo[first].scrolloff == 9 and vim.wo[second].scrolloff == 7, "per-window preferences were lost")

-- Preserve a prior deliberate semantic-token disable and later user options.
vim.lsp.semantic_tokens.enable(false, { bufnr = buf })
change(vim.g.bigfile.huge + 1)
vim.wo.scrolloff = 12
change(10, "BufWritePre")
assert(not vim.lsp.semantic_tokens.is_enabled({ bufnr = buf }), "overrode user semantic-token preference")
assert(vim.wo.scrolloff == 12, "overrode a newer user window preference")

-- Background buffer updates must not alter the current buffer's UI.
vim.cmd.enew()
local current = vim.api.nvim_get_current_buf()
local before = vim.wo.scrolloff
change(vim.g.bigfile.huge + 1)
assert(vim.api.nvim_get_current_buf() == current and vim.wo.scrolloff == before, "background event changed current UI")

print("bigfile lifecycle checks passed")
