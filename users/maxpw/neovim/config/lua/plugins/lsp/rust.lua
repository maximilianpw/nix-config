return {
  "rustaceanvim",
  ft = { "rust" },
  -- rustaceanvim reads vim.g.rustaceanvim from its ftplugin, so set it before loading.
  before = function()
    vim.g.rustaceanvim = {
      -- LSP configuration
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            numThreads = 4,
            cargo = {
              allFeatures = false,
              -- Build scripts + proc macros enabled: without them rust-analyzer
              -- produces phantom errors on any serde/tokio-style crate.
              buildScripts = {
                enable = true,
              },
            },
            checkOnSave = true,
            check = {
              command = "check",
            },
            procMacro = {
              enable = true,
            },
            diagnostics = {
              enable = true,
              experimental = {
                enable = false,
              },
              disabled = {},
              warningsAsHint = {},
              warningsAsInfo = {},
            },
            inlayHints = {
              bindingModeHints = {
                enable = false,
              },
              chainingHints = {
                enable = true,
              },
              closingBraceHints = {
                minLines = 25,
              },
              closureReturnTypeHints = {
                enable = "never",
              },
              lifetimeElisionHints = {
                enable = "never",
                useParameterNames = false,
              },
              maxLength = 25,
              parameterHints = {
                enable = true,
              },
              reborrowHints = {
                enable = "never",
              },
              renderColons = true,
              typeHints = {
                enable = true,
                hideClosureInitialization = false,
                hideNamedConstructor = false,
              },
            },
          },
        },
      },
      -- DAP configuration (disabled as requested)
      dap = {
        adapter = false,
      },
    }
  end,
}
