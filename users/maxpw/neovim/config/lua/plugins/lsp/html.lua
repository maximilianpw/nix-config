return {
  "nvim-ts-autotag",
  ft = {
    "html",
    "xml",
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "svelte",
    "php",
    "markdown",
  },
  after = function()
    require("nvim-ts-autotag").setup({})
  end,
}
