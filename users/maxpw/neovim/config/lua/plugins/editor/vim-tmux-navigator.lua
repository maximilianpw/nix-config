-- Outside tmux the plugin only runs wincmd, so in a Rex pane each key moves to
-- the next Rex pane once no Neovim window lies that way. Rex's own ctrl+hjkl
-- bindings (files/managed/.config/rex/init.lua) pass the keys through to Neovim.
local function navigate(wincmd, command, direction)
  return function()
    if vim.env.TMUX or not vim.env.REX_SESSION or vim.fn.executable("rex") == 0 then
      vim.cmd(command)
      return
    end
    local window = vim.api.nvim_get_current_win()
    vim.cmd.wincmd(wincmd)
    if vim.api.nvim_get_current_win() == window then
      vim.system({ "rex", "focus", direction })
    end
  end
end

return {
  "vim-tmux-navigator",
  event = "DeferredUIEnter",
  before = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    { "<C-h>", navigate("h", "TmuxNavigateLeft", "left"), desc = "Navigate left (tmux/Rex/nvim)" },
    { "<C-j>", navigate("j", "TmuxNavigateDown", "down"), desc = "Navigate down (tmux/Rex/nvim)" },
    { "<C-k>", navigate("k", "TmuxNavigateUp", "up"), desc = "Navigate up (tmux/Rex/nvim)" },
    { "<C-l>", navigate("l", "TmuxNavigateRight", "right"), desc = "Navigate right (tmux/Rex/nvim)" },
  },
}
