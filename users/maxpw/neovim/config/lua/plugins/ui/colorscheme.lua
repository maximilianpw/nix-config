-- Colorscheme. Loaded eagerly with high priority so it applies before other UI plugins.
return {
  "catppuccin",
  lazy = false,
  priority = 1000,
  after = function()
    require("catppuccin").setup({
      flavour = "mocha",
    })
    vim.cmd.colorscheme("catppuccin")
  end,
}
