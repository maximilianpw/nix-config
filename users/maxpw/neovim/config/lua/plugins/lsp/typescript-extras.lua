return {
  {
    "twoslash-queries.nvim",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    after = function()
      require("twoslash-queries").setup({
        multi_line = true,
        is_enabled = false,
        highlight = "Comment",
      })
    end,
    keys = {
      {
        "<leader>tq",
        function()
          local ok, twoslash = pcall(require, "twoslash-queries")
          if not ok then
            vim.notify("twoslash-queries.nvim not found: " .. tostring(twoslash), vim.log.levels.ERROR)
            return
          end

          if twoslash.config.is_enabled then
            vim.cmd("TwoslashQueriesDisable")
            vim.notify("TwoSlash queries disabled", vim.log.levels.INFO)
          else
            vim.cmd("TwoslashQueriesEnable")
            vim.notify("TwoSlash queries enabled", vim.log.levels.INFO)
          end
        end,
        desc = "Toggle TwoSlash Queries",
      },
      {
        "<leader>ti",
        "<cmd>TwoslashQueriesInspect<cr>",
        desc = "Inspect TwoSlash Query",
      },
    },
  },
  {
    "tsc.nvim",
    ft = { "typescript", "typescriptreact" },
    cmd = "TSC",
    after = function()
      require("tsc").setup({
        auto_open_qflist = true,
        pretty_errors = false,
        flags = {
          noEmit = true,
          pretty = "false",
        },
      })
    end,
    keys = {
      {
        "<leader>tc",
        "<cmd>TSC<cr>",
        desc = "Run TypeScript Compiler",
      },
    },
  },
}
