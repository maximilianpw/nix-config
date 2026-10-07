local M = {}

function M.setup(dap)
  local dap_utils = require("dap.utils")

  local function rust_program()
    return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
  end

  local ok_dap_go, dap_go = pcall(require, "dap-go")
  if ok_dap_go then
    dap_go.setup({
      dap_configurations = {
        {
          type = "go",
          name = "Attach remote",
          mode = "remote",
          request = "attach",
        },
      },
      delve = {
        path = "dlv",
        initialize_timeout_sec = 20,
        port = "${port}",
        args = {},
        build_flags = "",
      },
    })
  end

  dap.adapters.lldb = {
    type = "executable",
    command = "lldb-dap",
    name = "lldb",
  }

  dap.configurations.rust = {
    {
      name = "Launch file",
      type = "lldb",
      request = "launch",
      program = rust_program,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = {},
    },
    {
      name = "Launch file with args",
      type = "lldb",
      request = "launch",
      program = rust_program,
      cwd = "${workspaceFolder}",
      stopOnEntry = false,
      args = function()
        local args_string = vim.fn.input("Arguments: ")
        return dap_utils.splitstr(args_string)
      end,
    },
    {
      name = "Attach to process",
      type = "lldb",
      request = "attach",
      pid = dap_utils.pick_process,
      args = {},
    },
  }
end

return M
