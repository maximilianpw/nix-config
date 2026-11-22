-- The app keeps themes in a settings blob keyed by a generated ID, so they can
-- only be imported (modules/rex/darwin.nix). The app reads this path on its own
-- machine: run the action from a session on Joyce's server.
rex.action({
  name = "import_catppuccin_macchiato",
  title = "Import Catppuccin Macchiato Theme",
  category = "Appearance",
  keywords = "theme catppuccin macchiato",
  run = function()
    rex.client.queue("client.theme.import", {
      path = os.getenv("HOME") .. "/.config/rex/themes/catppuccin-macchiato",
    })
  end,
})
