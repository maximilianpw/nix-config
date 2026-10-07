-- Config module index. Nixvim applies the declarative options and globals in
-- users/maxpw/neovim/options.nix before this runs; keep this order:
-- options -> bigfile -> keymaps -> autocmds -> VS Code bridge -> plugins.
require("config.options")
require("config.bigfile")
require("config.keymaps")
require("config.autocmds")

-- vscode-neovim keymap bridge (no-op outside VS Code/Cursor)
require("config.vscode")

require("config.plugins").setup()
