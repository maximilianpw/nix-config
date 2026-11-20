return {
  {
    "typescript-tools.nvim",
    ft = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
    before = function()
      require("config.plugins").trigger("nvim-lspconfig")
    end,
    after = function()
      local ok_ts, typescript_tools = pcall(require, "typescript-tools")
      if not ok_ts then
        vim.notify("typescript-tools.nvim not found: " .. tostring(typescript_tools), vim.log.levels.ERROR)
        return
      end

      local setup_opts = {
        on_attach = function(client, bufnr)
          local ok, twoslash = pcall(require, "twoslash-queries")
          if ok then
            twoslash.attach(client, bufnr)
          end
        end,
        -- Buffer-local semantic token policy is owned by config.bigfile.
        settings = {
          expose_as_code_action = "all",
          tsserver_file_preferences = {
            includeInlayParameterNameHints = "literals",
          },
        },
      }

      typescript_tools.setup(setup_opts)
    end,
  },
  {
    "ts-error-translator.nvim",
    ft = { "typescript", "typescriptreact" },
    after = function()
      require("ts-error-translator").setup({})
    end,
  },
  {
    "package-info.nvim",
    -- Only relevant for package.json, not every JSON file
    event = "BufRead package.json",
    after = function(plugin)
      require("package-info").setup(plugin.opts)
    end,
    opts = {
      highlights = {
        up_to_date = {
          fg = "#3C4048",
        },
        outdated = {
          fg = "#fc514e",
        },
      },
    },
  },
}
