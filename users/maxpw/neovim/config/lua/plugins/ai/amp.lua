local opts = { auto_start = true, log_level = "info" }

return {
  "amp.nvim",
  event = "DeferredUIEnter",
  opts = opts,
  after = function()
    require("amp").setup(opts)
  end,
}
