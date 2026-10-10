-- oil.nvim: edit a directory listing like a buffer. Neo-tree keeps ownership of
-- directory buffers (`nvim .`, `:e dir/`); oil opens only through `-`/`:Oil`.
local opts = {
  default_file_explorer = false,
  delete_to_trash = true,
  skip_confirm_for_simple_edits = true,
  watch_for_changes = true,
  view_options = { show_hidden = true },
  keymaps = {
    -- <C-h>/<C-l> stay tmux/window navigation; move oil's split and refresh.
    ["<C-h>"] = false,
    ["<C-l>"] = false,
    ["<C-x>"] = { "actions.select", opts = { horizontal = true } },
    ["gR"] = "actions.refresh",
  },
}

return {
  "oil.nvim",
  cmd = "Oil",
  keys = {
    { "-", "<cmd>Oil<cr>", desc = "Open Parent Directory (oil)" },
  },
  after = function()
    require("oil").setup(opts)
  end,
}
