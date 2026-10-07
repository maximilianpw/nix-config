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
        -- typescript-tools handles root_dir automatically
        -- It looks for: tsconfig.json, jsconfig.json, package.json, .git
        single_file_support = true,
        on_attach = function(client, bufnr)
          local ok, twoslash = pcall(require, "twoslash-queries")
          if ok then
            twoslash.attach(client, bufnr)
          end
        end,
        -- Buffer-local semantic token policy is owned by config.bigfile.
        settings = {
          separate_diagnostic_server = true,
          publish_diagnostic_on = "insert_leave",
          expose_as_code_action = "all",
          debounce_text_changes = 300, -- Debounce to reduce server load
          tsserver_file_preferences = {
            includeInlayParameterNameHints = "literals",
            includeInlayParameterNameHintsWhenArgumentMatchesName = false,
            includeInlayFunctionParameterTypeHints = false,
            includeInlayVariableTypeHints = false,
            includeInlayPropertyDeclarationTypeHints = false,
            includeInlayFunctionLikeReturnTypeHints = false,
            includeInlayEnumMemberValueHints = false,
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
