return {
  -- Lua dev ergonomics (luv/vim types for better completion)
  {
    "lazydev.nvim",
    ft = "lua",
    after = function(plugin)
      require("lazydev").setup(plugin.opts)
    end,
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },

  -- Native LSP configuration
  {
    "nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    after = function()
      -- Diagnostics UI
      vim.diagnostic.config({
        virtual_text = {
          spacing = 4,
          source = "if_many",
          prefix = "●",
          severity = { min = vim.diagnostic.severity.WARN }, -- Only show warnings+
        },
        float = {
          source = true,
          border = "rounded",
          header = "",
          prefix = "",
          focusable = true, -- Allow interacting with diagnostic floats
          max_width = 80,
        },
        signs = {
          severity = { min = vim.diagnostic.severity.HINT },
          priority = 20, -- Show diagnostics above other signs
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = " ",
            [vim.diagnostic.severity.INFO] = " ",
          },
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
        jump = { float = true }, -- Show float when jumping to diagnostic
      })

      -- Inject schemastore schemas into jsonls/yamlls. schemastore.nvim is a
      -- Nix start plugin, so it is always on the runtimepath.
      local ok_schema, schemastore = pcall(require, "schemastore")
      if ok_schema then
        vim.lsp.config("jsonls", {
          settings = {
            json = {
              schemas = schemastore.json.schemas(),
            },
          },
        })
        vim.lsp.config("yamlls", {
          settings = {
            yaml = {
              schemas = schemastore.yaml.schemas(),
            },
          },
        })
      end

      -- Enable all LSP servers (configs loaded from lsp/ directory)
      -- Note: rust-analyzer is managed by rustaceanvim
      local servers = {
        "astro",
        "bashls",
        "biome",
        "cssls",
        "dockerls",
        "eslint",
        "gopls",
        "html",
        "jsonls",
        "lua_ls",
        "nil_ls",
        "nushell",
        "tailwindcss",
        "taplo",
        "yamlls",
        "zls",
      }
      vim.lsp.enable(servers)

      -- LspAttach autocmd for keybindings
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("native-lsp-attach", { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if not client then
            return
          end

          local bufnr = event.buf

          -- Enable completion triggered by <c-x><c-o>
          vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

          -- Keymaps
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = bufnr, desc = "LSP: " .. desc })
          end

          local ok_snacks, snacks = pcall(require, "snacks")
          map("gd", ok_snacks and snacks.picker.lsp_definitions or vim.lsp.buf.definition, "Goto Definition")
          map("gr", ok_snacks and snacks.picker.lsp_references or vim.lsp.buf.references, "Goto References")
          map(
            "gI",
            ok_snacks and snacks.picker.lsp_implementations or vim.lsp.buf.implementation,
            "Goto Implementation"
          )
          map(
            "gt",
            ok_snacks and snacks.picker.lsp_type_definitions or vim.lsp.buf.type_definition,
            "Goto Type Definition"
          )
          map("<leader>cr", vim.lsp.buf.rename, "Rename")
          map("<leader>ca", vim.lsp.buf.code_action, "Code Action", { "n", "x" })
          map("gD", vim.lsp.buf.declaration, "Goto Declaration")
          map("K", vim.lsp.buf.hover, "Hover Documentation")
          map("<leader>cs", vim.lsp.buf.signature_help, "Signature Documentation")
          map("<leader>Q", vim.diagnostic.open_float, "Show line diagnostics")
          -- Formatting keys and policy are owned by plugins/style/autoformat.lua.

          -- Inlay hints toggle
          if vim.lsp.inlay_hint then
            map("<leader>ci", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
            end, "Toggle Inlay Hints")
          end

          -- Document highlighting of the symbol under the cursor is handled by
          -- snacks.nvim's `words` module (see plugins/ui/snacks.lua).
        end,
      })
    end,
  },
}
