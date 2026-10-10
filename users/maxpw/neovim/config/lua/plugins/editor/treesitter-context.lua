-- Keeps the enclosing function/class header visible while scrolling.
local opts = {
  max_lines = 3,
  multiline_threshold = 3,
  -- Decided when a buffer is read; buffers that later grow past the threshold
  -- keep their context until reopened.
  on_attach = function(bufnr)
    return not _G.is_bigfile(bufnr, "max_ts")
  end,
}

return {
  "nvim-treesitter-context",
  event = { "BufReadPost", "BufNewFile" },
  keys = {
    { "<leader>uc", "<cmd>TSContext toggle<cr>", desc = "Toggle Treesitter Context" },
  },
  after = function()
    require("treesitter-context").setup(opts)
  end,
}
