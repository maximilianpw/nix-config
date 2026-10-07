local M = {}

function M.setup(dap, dapui)
  dapui.setup({
    icons = { expanded = "▾", collapsed = "▸", current_frame = "*" },
    controls = {
      enabled = true,
      element = "repl",
      icons = {
        pause = "⏸",
        play = "▶",
        step_into = "⏎",
        step_over = "⏭",
        step_out = "⏮",
        step_back = "b",
        run_last = "▶▶",
        terminate = "⏹",
        disconnect = "⏏",
      },
    },
    layouts = {
      {
        elements = {
          { id = "scopes", size = 0.25 },
          "breakpoints",
          "stacks",
          "watches",
        },
        size = 40,
        position = "left",
      },
      {
        elements = {
          "repl",
          "console",
        },
        size = 0.25,
        position = "bottom",
      },
    },
    floating = {
      max_height = nil,
      max_width = nil,
      border = "single",
      mappings = {
        close = { "q", "<Esc>" },
      },
    },
    mappings = {
      edit = "e",
      expand = { "<CR>", "o" },
      open = "o",
      remove = "d",
      repl = "r",
      toggle = "t",
    },
    element_mappings = {},
    expand_lines = false,
    force_buffers = false,
    render = {
      indent = 1,
      max_value_lines = 100,
    },
  })

  vim.api.nvim_set_hl(0, "DapBreakpoint", { fg = "#e51400" })
  vim.api.nvim_set_hl(0, "DapBreakpointCondition", { fg = "#f89c1c" })
  vim.api.nvim_set_hl(0, "DapBreakpointRejected", { fg = "#848484" })
  vim.api.nvim_set_hl(0, "DapLogPoint", { fg = "#61afef" })
  vim.api.nvim_set_hl(0, "DapStopped", { fg = "#ffcc00" })
  vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#555530" })

  local breakpoint_icons = {
    Breakpoint = "●",
    BreakpointCondition = "◉",
    BreakpointRejected = "○",
    LogPoint = "◆",
    Stopped = "▶",
  }

  vim.fn.sign_define("DapBreakpoint", {
    text = breakpoint_icons.Breakpoint,
    texthl = "DapBreakpoint",
    linehl = "",
    numhl = "DapBreakpoint",
  })
  vim.fn.sign_define("DapBreakpointCondition", {
    text = breakpoint_icons.BreakpointCondition,
    texthl = "DapBreakpointCondition",
    linehl = "",
    numhl = "DapBreakpointCondition",
  })
  vim.fn.sign_define("DapBreakpointRejected", {
    text = breakpoint_icons.BreakpointRejected,
    texthl = "DapBreakpointRejected",
    linehl = "",
    numhl = "DapBreakpointRejected",
  })
  vim.fn.sign_define("DapLogPoint", {
    text = breakpoint_icons.LogPoint,
    texthl = "DapLogPoint",
    linehl = "",
    numhl = "DapLogPoint",
  })
  vim.fn.sign_define("DapStopped", {
    text = breakpoint_icons.Stopped,
    texthl = "DapStopped",
    linehl = "DapStoppedLine",
    numhl = "DapStopped",
  })

  local ok_virtual_text, nvim_dap_virtual_text = pcall(require, "nvim-dap-virtual-text")
  if ok_virtual_text then
    nvim_dap_virtual_text.setup({
      enabled = true,
      enable_commands = true,
      highlight_changed_variables = true,
      highlight_new_as_changed = false,
      show_stop_reason = true,
      commented = false,
      only_first_definition = true,
      all_references = false,
      clear_on_continue = false,
      filter_references_pattern = "<module",
      virt_text_pos = vim.fn.has("nvim-0.10") == 1 and "inline" or "eol",
      all_frames = false,
      virt_lines = false,
      virt_lines_above = false,
      virt_text_win_col = nil,
      text_prefix = "",
      separator = " | ",
      error_prefix = "✖ ",
      info_prefix = "ℹ ",
      display_callback = function(variable, _buf, _stackframe, _node, options)
        if options.virt_text_pos == "inline" then
          return " = " .. variable.value
        end
        return variable.name .. " = " .. variable.value
      end,
    })
  end

  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end
end

return M
