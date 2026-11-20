-- Only the options that differ from neo-tree's defaults.
local spec = {
  "neo-tree.nvim",
  cmd = "Neotree",
  keys = {
    {
      "<leader>e",
      function()
        require("neo-tree.command").execute({ toggle = true })
      end,
      desc = "Toggle File Explorer",
    },
    {
      "<leader>o",
      function()
        require("neo-tree.command").execute({ toggle = false, reveal = true })
      end,
      desc = "Focus File Explorer",
    },
  },
  opts = {
    auto_clean_after_session_restore = true,
    popup_border_style = "rounded",
    open_files_do_not_replace_types = { "terminal", "qf" },
    default_component_configs = {
      indent = {
        with_expanders = true,
        expander_collapsed = "",
        expander_expanded = "",
      },
      modified = { symbol = "[+]" },
      git_status = {
        symbols = {
          modified = "",
          untracked = "",
          ignored = "",
          staged = "",
          conflict = "",
        },
      },
      type = { required_width = 122 },
      created = { enabled = true, required_width = 110 },
    },
    window = {
      mappings = {
        ["m"] = { "move", config = { show_path = "relative" } },
        ["Z"] = "expand_all_nodes",
        ["i"] = "show_file_details",
      },
    },
    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,
      window = {
        mappings = {
          ["<c-x>"] = "clear_filter",
        },
      },
    },
    buffers = {
      show_unloaded = true,
    },
  },
}

local window_picker = {
  hint = "floating-big-letter",
  filter_rules = {
    include_current_win = false,
    autoselect_one = true,
    bo = {
      filetype = { "neo-tree", "neo-tree-popup", "snacks_notif" },
      buftype = { "terminal", "quickfix" },
    },
  },
}

spec.after = function()
  require("config.plugins").packadd("nvim-window-picker")
  require("window-picker").setup(window_picker)
  require("neo-tree").setup(spec.opts)
end

return spec
