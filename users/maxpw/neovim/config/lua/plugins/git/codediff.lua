-- codediff.nvim: repository review and side-by-side diffs. Its native diff
-- library is built by nixpkgs (users/maxpw/neovim/plugins.nix), never downloaded.
return {
  "codediff.nvim",
  cmd = "CodeDiff",
  keys = {
    { "<leader>gd", "<cmd>CodeDiff<cr>", desc = "Diff Repository (CodeDiff)" },
    { "<leader>gD", "<cmd>CodeDiff history<cr>", desc = "Git History (CodeDiff)" },
  },
  after = function()
    -- Its file watcher would otherwise be downloaded into the read-only plugin
    -- directory; without it codediff refreshes by polling.
    vim.env.CODEDIFF_WATCHER_NO_AUTO_INSTALL = "1"
    require("codediff").setup({})
  end,
}
