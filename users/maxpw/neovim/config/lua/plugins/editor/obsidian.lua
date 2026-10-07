-- Community-maintained fork of epwalsh/obsidian.nvim (the original is unmaintained).
-- Commands are `:Obsidian <subcommand>`; default buffer mappings (<CR> smart action,
-- gf link follow, ]o/[o link nav) come with the plugin.
local spec = {
  "obsidian.nvim",
  ft = "markdown",
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/Documents/obsidian vault",
      },
    },
    legacy_commands = false,
    callbacks = {
      enter_note = function()
        vim.keymap.set("n", "<leader>ch", "<cmd>Obsidian toggle_checkbox<cr>", {
          buffer = true,
          desc = "Toggle checkbox",
        })
      end,
    },
  },
  after = function(plugin)
    require("obsidian").setup(plugin.opts)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      group = vim.api.nvim_create_augroup("obsidian-conceal", { clear = true }),
      callback = function()
        vim.opt_local.conceallevel = 2
      end,
    })
  end,
  keys = {
    { "<leader>On", "<cmd>Obsidian new<cr>", desc = "New Note" },
    { "<leader>Oo", "<cmd>Obsidian search<cr>", desc = "Search Notes" },
    { "<leader>Oq", "<cmd>Obsidian quick_switch<cr>", desc = "Quick Switch" },
    { "<leader>Ob", "<cmd>Obsidian backlinks<cr>", desc = "Backlinks" },
    { "<leader>Ot", "<cmd>Obsidian tags<cr>", desc = "Tags" },
    { "<leader>Od", "<cmd>Obsidian today<cr>", desc = "Today's Note" },
    { "<leader>Oy", "<cmd>Obsidian yesterday<cr>", desc = "Yesterday's Note" },
    { "<leader>Ol", ":Obsidian link<cr>", desc = "Link", mode = "v" },
    { "<leader>OL", ":Obsidian link_new<cr>", desc = "Link New", mode = "v" },
  },
}

return spec
