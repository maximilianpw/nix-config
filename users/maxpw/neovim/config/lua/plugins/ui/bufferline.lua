-- Buffer line configuration for tab/buffer management
return {
  "bufferline.nvim",
  event = "DeferredUIEnter",
  keys = {
    { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle Pin" },
    { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete Non-Pinned Buffers" },
    { "<leader>br", "<Cmd>BufferLineCloseRight<CR>", desc = "Delete Buffers to the Right" },
    { "<leader>bl", "<Cmd>BufferLineCloseLeft<CR>", desc = "Delete Buffers to the Left" },
    { "<leader>bo", "<Cmd>BufferLineCloseOthers<CR>", desc = "Delete Other Buffers" },
    { "<S-h>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
    { "<S-l>", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
    { "[b", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" },
    { "]b", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
    { "[B", "<cmd>BufferLineMovePrev<cr>", desc = "Move buffer prev" },
    { "]B", "<cmd>BufferLineMoveNext<cr>", desc = "Move buffer next" },
  },
  opts = {
    options = {
      -- Use Snacks bufdelete for better buffer management
      close_command = function(n)
        require("snacks").bufdelete(n)
      end,
      right_mouse_command = function(n)
        require("snacks").bufdelete(n)
      end,
      diagnostics = "nvim_lsp",
      always_show_bufferline = false,
      diagnostics_indicator = function(_, _, diag)
        -- Use standard diagnostic icons instead of LazyVim icons
        local icons = {
          Error = "󰅚 ",
          Warn = "󰀪 ",
          Hint = "󰌶 ",
          Info = "󰋽 ",
        }
        local ret = (diag.error and icons.Error .. diag.error .. " " or "")
          .. (diag.warning and icons.Warn .. diag.warning or "")
        return vim.trim(ret)
      end,
      offsets = {
        {
          filetype = "snacks_dashboard",
          text = "Dashboard",
          highlight = "Directory",
          text_align = "left",
        },
      },
      -- Simplified icon function without LazyVim dependency
      get_element_icon = function(opts)
        local devicons_ok, devicons = pcall(require, "nvim-web-devicons")
        if devicons_ok then
          local icon, hl = devicons.get_icon(opts.path, opts.extension, { default = true })
          return icon, hl
        end
        return "", ""
      end,
    },
  },
  after = function(plugin)
    require("bufferline").setup(plugin.opts)

    -- Coalesce session-restoration events. defer_fn closes its timer for us.
    local pending = false
    vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
      group = vim.api.nvim_create_augroup("bufferline-session-refresh", { clear = true }),
      callback = function()
        if pending then
          return
        end
        pending = true
        vim.defer_fn(function()
          pending = false
          vim.cmd.redrawtabline()
        end, 100)
      end,
    })
  end,
}
