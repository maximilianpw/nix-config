local M = {}

-- The deployed config is an immutable Nix store path. Editing actions should
-- open the nix-config checkout instead; rebuild to deploy the change.
function M.editable_config_dir()
  -- Build the list densely: a nil override must not end ipairs early.
  local candidates = {}
  if vim.g.maxpw_nvim_source then
    table.insert(candidates, vim.g.maxpw_nvim_source)
  end
  if vim.env.HOME then
    table.insert(candidates, vim.fs.joinpath(vim.env.HOME, "nix-config", "users", "maxpw", "neovim", "config"))
  end
  for _, dir in ipairs(candidates) do
    if vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  vim.notify("Editable Neovim source not found; showing the read-only deployed config", vim.log.levels.WARN)
  return vim.g.maxpw_nvim_config_dir or vim.fn.stdpath("config")
end

return M
