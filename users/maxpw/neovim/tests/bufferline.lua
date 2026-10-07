-- Deferred-redraw contract, run by tests/plugins.lua with the real plugin loaded.
local root = assert(vim.env.NVIM_CONFIG_TEST_ROOT)
assert(package.loaded.bufferline, "load bufferline.nvim before this contract")

local spec = dofile(root .. "/lua/plugins/ui/bufferline.lua")
spec.after(spec)
spec.after(spec)
local group = "bufferline-session-refresh"
assert(#vim.api.nvim_get_autocmds({ group = group }) == 2, "bufferline reload accumulated autocmds")

-- Observe the real redraw command rather than inventing a plugin refresh API.
-- Count only the config's debounced redraws: with the real plugin loaded,
-- bufferline's own renderer also schedules redraws whenever the tabline draws.
local redrawtabline, count = vim.cmd.redrawtabline, 0
vim.cmd.redrawtabline = function(...)
  if debug.traceback():find("plugins/ui/bufferline.lua", 1, true) then
    count = count + 1
  end
  return redrawtabline(...)
end
local previous_error = vim.v.errmsg
vim.v.errmsg = ""
local ok, err = pcall(function()
  for burst = 1, 2 do
    vim.api.nvim_exec_autocmds("BufAdd", { group = group })
    vim.api.nvim_exec_autocmds("BufDelete", { group = group })
    vim.api.nvim_exec_autocmds("BufAdd", { group = group })
    assert(count == burst - 1, "bufferline redraw was not deferred")
    -- Wait past the timer deadline to catch duplicate redraws and async errors.
    vim.wait(250, function()
      return vim.v.errmsg ~= ""
    end)
    assert(vim.v.errmsg == "", vim.v.errmsg)
    assert(count == burst, "bufferline did not coalesce events or reset its pending flag")
  end
end)
vim.cmd.redrawtabline = redrawtabline
vim.v.errmsg = previous_error
assert(ok, err)
print("bufferline deferred redraw contracts passed")
