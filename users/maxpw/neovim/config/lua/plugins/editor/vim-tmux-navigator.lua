return {
  "vim-tmux-navigator",
  event = "DeferredUIEnter",
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Navigate left (tmux/nvim)" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Navigate down (tmux/nvim)" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Navigate up (tmux/nvim)" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Navigate right (tmux/nvim)" },
  },
}
