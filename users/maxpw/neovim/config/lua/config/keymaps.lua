-- Basic keymaps (non-plugin)

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- vim.snippet sessions survive <Esc>, and a stale session would keep <Tab>
-- jumping back into the snippet instead of indenting.
vim.keymap.set({ "i", "s" }, "<Esc>", function()
  if vim.snippet.active() then
    vim.snippet.stop()
  end
  return "<Esc>"
end, { expr = true, desc = "Escape and end snippet" })

-- Native multicursors: the default <C-l> clears them, but <C-l> is tmux
-- navigation here. Clearing the namespace is the documented alternative.
vim.keymap.set("n", "<C-q>", function()
  vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace("nvim.multicursor"), 0, -1)
end, { desc = "Clear multicursors" })

-- Neovim's grr/grn/gra/... LSP defaults would make the `gr` references picker
-- wait for 'timeoutlen'; their actions live under <leader>c and g instead.
for _, mode in ipairs({ "n", "x" }) do
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if map.lhs:match("^gr.") then
      vim.keymap.del(mode, map.lhs)
    end
  end
end

vim.keymap.set("n", "<leader>uu", function()
  vim.cmd.packadd("nvim.undotree")
  vim.cmd.Undotree()
end, { desc = "Undo Tree" })

-- Exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Copy file path with line number/range
vim.keymap.set({ "n", "v" }, "<leader>yd", function()
  local filepath = vim.fn.expand("%")
  local start_line = vim.fn.line(".")
  local end_line = vim.fn.line("v")

  local text
  if vim.fn.mode() == "v" or vim.fn.mode() == "V" or vim.fn.mode() == "\22" then
    start_line = vim.fn.line("v")
    end_line = vim.fn.line(".")
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    text = string.format("%s:%d-%d", filepath, start_line, end_line)
  else
    text = string.format("%s:%d", filepath, start_line)
  end

  vim.fn.setreg("+", text)
  vim.notify("Copied: " .. text, vim.log.levels.INFO)
end, { desc = "Copy file path with line number/range" })

-- Better buffer navigation
vim.keymap.set("n", "<leader>bf", "<cmd>bfirst<cr>", { desc = "First buffer" })
vim.keymap.set("n", "<leader>bL", "<cmd>blast<cr>", { desc = "Last buffer" })

-- Quickfix navigation
vim.keymap.set("n", "[q", "<cmd>cprevious<cr>", { desc = "Previous quickfix" })
vim.keymap.set("n", "]q", "<cmd>cnext<cr>", { desc = "Next quickfix" })
vim.keymap.set("n", "[Q", "<cmd>cfirst<cr>", { desc = "First quickfix" })
vim.keymap.set("n", "]Q", "<cmd>clast<cr>", { desc = "Last quickfix" })

-- Better visual indentation (stay in visual mode)
vim.keymap.set("v", "<", "<gv", { desc = "Indent left and reselect" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and reselect" })

-- Window resize with arrows
vim.keymap.set("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
vim.keymap.set("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
vim.keymap.set("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
vim.keymap.set("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })
