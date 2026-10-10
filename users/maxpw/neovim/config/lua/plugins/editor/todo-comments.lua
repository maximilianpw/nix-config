-- todo-comments owns TODO/FIXME/HACK/NOTE highlighting; search results go to
-- the quickfix list, which quicker.nvim displays.
local opts = {
  signs = false,
}

return {
  "todo-comments.nvim",
  event = { "BufReadPost", "BufNewFile" },
  keys = {
    {
      "]t",
      function()
        require("todo-comments").jump_next()
      end,
      desc = "Next TODO Comment",
    },
    {
      "[t",
      function()
        require("todo-comments").jump_prev()
      end,
      desc = "Previous TODO Comment",
    },
    { "<leader>st", "<cmd>TodoQuickFix<cr>", desc = "Search TODO Comments" },
  },
  after = function()
    require("todo-comments").setup(opts)
  end,
}
