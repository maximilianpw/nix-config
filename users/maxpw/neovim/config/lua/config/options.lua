-- Declarative options live in users/maxpw/neovim/options.nix. Only behavior
-- that is not a plain option assignment stays here.

-- Sync clipboard between OS and Neovim after startup; resolving the provider
-- eagerly measurably slows startup.
vim.schedule(function()
  vim.opt.clipboard = "unnamedplus"
end)
