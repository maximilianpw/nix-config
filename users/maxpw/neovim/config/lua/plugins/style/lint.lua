return {

  { -- Linting
    "nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    after = function()
      local lint = require("lint")
      local fs = require("util.fs")
      local tooling = require("util.tooling")

      -- Override oxlint args to pass the config file it finds
      local oxlint = lint.linters.oxlint
      oxlint.args = function()
        local cfg = vim.fs.find(tooling.oxlint, {
          upward = true,
          path = vim.fn.expand("%:p:h"),
        })
        if cfg[1] then
          return { "--format", "github", "-c", cfg[1] }
        end
        return { "--format", "github" }
      end

      -- JS/TS lint ownership: ESLint diagnostics/code actions come from the ESLint LSP;
      -- nvim-lint only adds non-LSP tools such as oxlint.
      local js_ts_fts = { "javascript", "javascriptreact", "typescript", "typescriptreact" }

      lint.linters_by_ft = {
        dockerfile = { "hadolint" },
        terraform = { "tflint" },
        text = { "vale" },
        java = { "checkstyle" },
        nix = { "nix" },
      }

      --- Check if a project has an oxlint config, repository-scoped.
      local function has_oxlint_config(bufnr)
        return fs.has_config(bufnr, tooling.oxlint)
      end

      --- Get the effective linter list for a buffer, including dynamic JS/TS linters
      local function get_linters(bufnr)
        local ft = vim.bo[bufnr].filetype
        local configured = lint.linters_by_ft[ft]
        local linters = configured and vim.list_slice(configured) or {}
        if vim.tbl_contains(js_ts_fts, ft) then
          if has_oxlint_config(bufnr) then
            table.insert(linters, "oxlint")
          end
        end
        return linters
      end

      local function run_linters(bufnr)
        bufnr = bufnr or vim.api.nvim_get_current_buf()
        if not vim.bo[bufnr].modifiable then
          return
        end
        if _G.is_bigfile and _G.is_bigfile(bufnr, "large") then
          return
        end
        local linters = get_linters(bufnr)
        if #linters > 0 then
          lint.try_lint(linters)
        end
      end

      local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

      -- FileType rather than BufEnter: the filetype is set, and switching
      -- windows does not re-lint.
      vim.api.nvim_create_autocmd({ "FileType", "InsertLeave", "BufWritePost" }, {
        group = lint_augroup,
        callback = function(ev)
          run_linters(ev.buf)
        end,
      })

      -- Manual command to run everything immediately
      vim.api.nvim_create_user_command("LintNow", function(opts)
        local all = opts.args == "all"
        if all then
          lint.try_lint()
        else
          run_linters()
        end
      end, { desc = "Run linters (add :LintNow all for raw try_lint)", nargs = "?" })
    end,
  },
}
