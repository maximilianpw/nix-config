local panes = require("panes")

-- These programs handle ctrl+hjkl themselves; Neovim hands focus back to Rex
-- at its own edges (users/maxpw/neovim/config/lua/plugins/editor/vim-tmux-navigator.lua).
local passthrough = {
  vi = true,
  vim = true,
  nvim = true,
  view = true,
  vimdiff = true,
  nvimdiff = true,
  fzf = true,
}

local function foreground_handles_navigation(ctx)
  local fg = panes.foreground(ctx.block_id)
  if not fg then
    return false
  end
  for _, name in ipairs({ fg.name or "", (fg.argv0 or ""):match("[^/]*$") or "" }) do
    if passthrough[name:lower()] then
      return true
    end
  end
  return false
end

local directions = { h = "left", j = "down", k = "up", l = "right" }

for key, direction in pairs(directions) do
  -- Returning false at a layout edge lets the key reach the terminal, so
  -- ctrl+l still clears a shell that has no pane to its right.
  rex.bind("ctrl+" .. key, function(ctx)
    if foreground_handles_navigation(ctx) then
      return false
    end
    local before = rex.session.view({})
    local after = rex.session.focus_direction({ direction = direction })
    return before ~= nil and after ~= nil and after.revision ~= before.revision
  end)
end

rex.mode("resize", { exclusive = true })
rex.bind("cmd+alt+r", "client.mode.enter", { name = "resize" })

local resize_keys = { left = "left", down = "down", up = "up", right = "right" }
for key, direction in pairs(directions) do
  resize_keys[key] = direction
end
for key, direction in pairs(resize_keys) do
  rex.bind("resize/" .. key, "pane.resize", { direction = direction })
  rex.bind("resize/shift+" .. key, "pane.resize", { direction = direction, amount = 15 })
end
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")

require("popups")
require("projects")
require("runs")
require("kim")
require("vev")
-- Palette action "Transfer pi Session to Host…" (also /transfer in pi).
require("transfer_pi_session")
require("theme")

-- cmd+g replaces the app's default Find Next shortcut.
rex.bind("cmd+g", "lazygit_float")
rex.bind("ctrl+cmd+d", "lazydocker_float")
rex.bind("cmd+o", "project_open")
rex.bind("cmd+e", "run_split")
rex.bind("cmd+j", "workspace_open")
rex.bind("cmd+u", "agents_fanout")
rex.bind("cmd+b", "pane.move_to_new_tab")
rex.bind("cmd+i", "kim_session")

-- Everything else sits behind one prefix, on the keys the Herdr prefix used
-- where the command existed there. Twice sends the prefix to the terminal.
local prefixed = {
  ["ctrl+space"] = { "pane.send_key", { key = "ctrl+space" } },
  [";"] = { "pane.focus_recent.in_tab" },
  ["shift+b"] = { "pane.move_to_new_tab" },
  ["shift+p"] = { "pane.rename" },
  o = { "project_open" },
  t = { "workspace_open" },
  ["shift+t"] = { "workspace_new" },
  ["alt+t"] = { "workspace_archive" },
  a = { "agents_fanout" },
  r = { "run_split" },
  ["alt+k"] = { "kim_session" },
  k = { "kim_top" },
  d = { "kim_dev" },
  v = { "vev_up" },
}
for key, binding in pairs(prefixed) do
  rex.bind("ctrl+space>" .. key, binding[1], binding[2])
end
