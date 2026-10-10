-- Useful plugin to show pending keybinds
local spec = {
  "which-key.nvim",
  event = "VimEnter",
  opts = {
    delay = 300,
    icons = {
      mappings = vim.g.have_nerd_font,
      keys = vim.g.have_nerd_font and {} or {
        Up = "<Up> ",
        Down = "<Down> ",
        Left = "<Left> ",
        Right = "<Right> ",
        C = "<C-…> ",
        M = "<M-…> ",
        D = "<D-…> ",
        S = "<S-…> ",
        CR = "<CR> ",
        Esc = "<Esc> ",
        ScrollWheelDown = "<ScrollWheelDown> ",
        ScrollWheelUp = "<ScrollWheelUp> ",
        NL = "<NL> ",
        BS = "<BS> ",
        Space = "<Space> ",
        Tab = "<Tab> ",
        F1 = "<F1>",
        F2 = "<F2>",
        F3 = "<F3>",
        F4 = "<F4>",
        F5 = "<F5>",
        F6 = "<F6>",
        F7 = "<F7>",
        F8 = "<F8>",
        F9 = "<F9>",
        F10 = "<F10>",
        F11 = "<F11>",
        F12 = "<F12>",
      },
    },

    -- Document existing key chains
    spec = {
      { "<leader>c", group = "Code", mode = { "n", "x" } },
      { "<leader>q", group = "Session/Diagnostics" },
      { "<leader>d", group = "Debug" },
      { "<leader>f", group = "Find" },
      { "<leader>t", group = "Test/Toggle" },
      { "<leader>g", group = "Git" },
      { "<leader>gh", group = "Git Hunk" },
      { "<leader>e", group = "Explorer" },
      { "<leader>s", group = "Search/Format" },
      { "<leader>S", desc = "Select Scratch Buffer" },
      { "<leader>n", group = "Notifications" },
      { "<leader>b", group = "Buffer" },
      { "<leader>y", group = "Yank" },
      { "<leader>O", group = "Obsidian" },
      { "<leader>u", group = "UI/Undo" },
      { "<leader>x", group = "Quickfix/Diagnostics" },
      { "<leader>D", desc = "Lazydocker" },
      -- Git hunk navigation
      { "]h", desc = "Next Hunk" },
      { "[h", desc = "Previous Hunk" },
      { "]H", desc = "Last Hunk" },
      { "[H", desc = "First Hunk" },
      -- Treesitter textobjects
      { "[f", desc = "Previous Function Start" },
      { "]f", desc = "Next Function Start" },
      { "[F", desc = "Previous Function End" },
      { "]F", desc = "Next Function End" },
      { "[c", desc = "Previous Class Start" },
      { "]c", desc = "Next Class Start" },
      { "[C", desc = "Previous Class End" },
      { "]C", desc = "Next Class End" },
      { "[a", desc = "Previous Parameter Start" },
      { "]a", desc = "Next Parameter Start" },
      { "[A", desc = "Previous Parameter End" },
      { "]A", desc = "Next Parameter End" },
      -- Mini editing helpers
      { "gS", desc = "Toggle Split/Join" },
      { "ga", desc = "Align" },
      { "gA", desc = "Align with Preview" },
      -- Noice scrolling
      { "<c-f>", desc = "Scroll Forward (LSP)", mode = { "i", "n", "s" } },
      { "<c-b>", desc = "Scroll Backward (LSP)", mode = { "i", "n", "s" } },
      -- Command mode
      { "<S-Enter>", desc = "Redirect Cmdline", mode = "c" },
    },
  },
}

spec.after = function()
  require("which-key").setup(spec.opts)
end

return spec
