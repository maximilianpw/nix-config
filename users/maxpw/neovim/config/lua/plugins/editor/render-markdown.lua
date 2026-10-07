local spec = {
  "render-markdown.nvim",
  before = function()
    require("config.plugins").trigger("nvim-treesitter")
  end,
  ft = { "markdown", "norg", "rmd", "org" },
  opts = {
    code = {
      sign = false,
      width = "block",
      right_pad = 1,
    },
    heading = {
      sign = false,
      icons = {},
    },
  },
}

spec.after = function()
  require("render-markdown").setup(spec.opts)
end

return spec
