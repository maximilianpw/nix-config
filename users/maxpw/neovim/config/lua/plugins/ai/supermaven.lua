-- The plugin is Nix-managed. Its completion engine (sm-agent) is downloaded by
-- the plugin into ~/.supermaven on first use: an approved runtime exception,
-- see docs/nixvim-hjem-migration-plan.md. It is not Nix-built or offline-capable.
local opts = {
  disable_inline_completion = false,
  disable_keymaps = false,
  -- <Tab> accepts suggestions contextually through Blink; keep <C-l> as a direct AI fallback.
  keymaps = { accept_suggestion = "<C-l>" },
}

return {
  "supermaven-nvim",
  event = "InsertEnter",
  opts = opts,
  after = function()
    require("supermaven-nvim").setup(opts)
  end,
}
