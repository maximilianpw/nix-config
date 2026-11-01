local terminal = "com.superlogical.terminal"

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
  local proc = rex.block.call(terminal, "process", { block_id = ctx.block_id })
  local fg = proc and proc.foreground
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
