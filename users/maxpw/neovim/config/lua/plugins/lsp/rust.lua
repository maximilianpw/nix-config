return {
  "rustaceanvim",
  ft = { "rust" },
  -- rustaceanvim reads vim.g.rustaceanvim from its ftplugin, so set it before loading.
  before = function()
    vim.g.rustaceanvim = {
      server = {
        default_settings = {
          ["rust-analyzer"] = {
            numThreads = 4,
          },
        },
      },
    }
  end,
}
