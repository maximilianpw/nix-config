-- Nix supplies the native fuzzy library; there is no build/download step.
local spec = {
  "fff.nvim",
  opts = {
    prompt = "❯ ",
    title = "Find Files",
    debug = {
      enabled = false,
      show_scores = false,
    },
  },
  lazy = false,
  keys = {
    {
      "<leader>ff",
      function()
        require("fff").find_files()
      end,
      desc = "Find Files",
    },
    {
      "<leader>fl",
      function()
        require("fff").live_grep()
      end,
      desc = "Find by Grep (Live)",
    },
    {
      "<leader>fz",
      function()
        require("fff").live_grep({
          grep = {
            modes = { "fuzzy", "plain" },
          },
        })
      end,
      desc = "Live Fuzzy Grep",
    },
    {
      "<leader>fc",
      function()
        require("fff").find_files_in_dir(require("util.source").editable_config_dir())
      end,
      desc = "Find Config Files (editable source)",
    },
    {
      "<leader>fw",
      function()
        require("fff").live_grep({
          query = vim.fn.expand("<cword>"),
        })
      end,
      desc = "Find Word Under Cursor",
    },
    {
      "<leader>fg",
      function()
        require("fff").find_in_git_root()
      end,
      desc = "Find in Git Root",
    },
  },
}

spec.after = function()
  require("fff").setup(spec.opts)
end

return spec
