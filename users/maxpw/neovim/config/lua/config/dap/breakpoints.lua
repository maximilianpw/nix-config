local M = {}

function M.setup()
  local ok_persistent_breakpoints, persistent_breakpoints = pcall(require, "persistent-breakpoints")
  if ok_persistent_breakpoints then
    persistent_breakpoints.setup({
      save_dir = vim.fn.stdpath("data") .. "/breakpoints",
      load_breakpoints_event = { "BufReadPost" },
      perf_record = false,
    })
    -- DAP loads on a keypress, after existing buffers' BufReadPost events.
    require("persistent-breakpoints.api").load_breakpoints()
  end
end

return M
