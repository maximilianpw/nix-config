-- quicker.nvim owns the quickfix and location-list windows. Diagnostics are
-- shown through the native lists rather than a separate panel plugin.
local diagnostics_title = "Diagnostics"

local function open_diagnostics(loclist)
  local set = loclist and vim.diagnostic.setloclist or vim.diagnostic.setqflist
  set({ open = false, title = diagnostics_title })
  require("quicker").open({ loclist = loclist, focus = true })
end

local opts = {
  keys = {
    {
      ">",
      function()
        require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
      end,
      desc = "Expand quickfix context",
    },
    {
      "<",
      function()
        require("quicker").collapse()
      end,
      desc = "Collapse quickfix context",
    },
  },
}

return {
  "quicker.nvim",
  ft = "qf",
  keys = {
    {
      "<leader>xq",
      function()
        require("quicker").toggle()
      end,
      desc = "Toggle Quickfix",
    },
    {
      "<leader>xl",
      function()
        require("quicker").toggle({ loclist = true })
      end,
      desc = "Toggle Location List",
    },
    {
      "<leader>xx",
      function()
        open_diagnostics(false)
      end,
      desc = "Workspace Diagnostics",
    },
    {
      "<leader>xX",
      function()
        open_diagnostics(true)
      end,
      desc = "Buffer Diagnostics",
    },
  },
  after = function()
    vim.cmd.packadd("cfilter")
    require("quicker").setup(opts)
    -- setqflist with a known title updates that list in place, so this only
    -- refreshes while the diagnostics list is the current quickfix list.
    vim.api.nvim_create_autocmd("DiagnosticChanged", {
      group = vim.api.nvim_create_augroup("diagnostics-quickfix", { clear = true }),
      callback = function()
        if vim.fn.getqflist({ title = 0 }).title == diagnostics_title then
          vim.diagnostic.setqflist({ open = false, title = diagnostics_title })
        end
      end,
    })
  end,
}
