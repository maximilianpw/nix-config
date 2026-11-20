-- Config module index. Nixvim applies the declarative options and globals in
-- users/maxpw/neovim/options.nix before this runs; keep this order:
-- options -> bigfile -> keymaps -> autocmds -> plugins.
require("config.options")
require("config.bigfile")
require("config.keymaps")
require("config.autocmds")

require("config.plugins").setup()
