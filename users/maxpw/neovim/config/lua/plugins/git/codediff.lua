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
    require("codediff").setup({})
  end,
}
