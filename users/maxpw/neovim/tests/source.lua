-- <leader>fc must open the editable nix-config checkout, not the read-only store config.
local root = assert(vim.env.NVIM_CONFIG_TEST_ROOT, "NVIM_CONFIG_TEST_ROOT is required")
vim.opt.runtimepath:prepend(root)
local source = require("util.source")

local home = vim.uv.fs_realpath(vim.fn.tempname()) or vim.fn.tempname()
vim.fn.mkdir(home, "p")
home = vim.uv.fs_realpath(home)
local checkout = vim.fs.joinpath(home, "nix-config", "users", "maxpw", "neovim", "config")
local override = vim.fs.joinpath(home, "elsewhere")
local deployed = vim.fs.joinpath(home, "deployed")
vim.env.HOME = home
vim.g.maxpw_nvim_source = nil
vim.g.maxpw_nvim_config_dir = deployed

local warnings = 0
vim.notify = function()
  warnings = warnings + 1
end

assert(source.editable_config_dir() == deployed and warnings == 1, "missing checkout did not fall back with a warning")

vim.fn.mkdir(checkout, "p")
assert(source.editable_config_dir() == checkout, "default checkout ignored when no override is set")

vim.g.maxpw_nvim_source = vim.fs.joinpath(home, "missing")
assert(source.editable_config_dir() == checkout, "missing override hid the default checkout")

vim.fn.mkdir(override, "p")
vim.g.maxpw_nvim_source = override
assert(source.editable_config_dir() == override, "existing override was not preferred")

vim.fn.delete(home, "rf")
print("editable source checks passed")
