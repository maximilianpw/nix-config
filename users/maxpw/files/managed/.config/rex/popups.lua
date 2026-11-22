local panes = require("panes")

local M = {}

function M.open(label, options, bounds)
  local _, err = rex.session.new_layer({
    bounds = bounds or { 0.05, 0.05, 0.9, 0.9 },
    focus = true,
    layout = panes.shell_block(label, options),
  })
  if err ~= nil then
    error(err, 0)
  end
end

local function find(window, label)
  for _, layer in ipairs(window.layers) do
    if layer.kind ~= "tiled" then
      for _, block in ipairs(layer.blocks) do
        local current = block.label or ""
        if current == label or current:sub(1, #label + 1) == label .. " " then
          return layer, block
        end
      end
    end
  end
end

local function set_state(layer, state, focus)
  local _, err = rex.session.set_layer_state({ layer_id = layer.layer_id, state = state, focus = focus })
  if err ~= nil then
    error(err, 0)
  end
end

-- An action that shows, hides (minimized, so the program keeps its state) and
-- restores one floating program in the active window. The pane's label is its
-- identity: a per_dir tool carries its directory, so it is reused only from
-- the same place.
function M.tool(spec)
  rex.action({
    name = spec.action,
    title = "Toggle " .. spec.title .. " Popup",
    keywords = spec.label,
    run = function(ctx)
      local view, err = rex.session.view({})
      if err ~= nil then
        error(err, 0)
      end
      local layer, block = find(panes.active_window(view), spec.label)
      if block and block.block_id == ctx.block_id then
        return set_state(layer, "minimized")
      end

      local cwd = panes.cwd(ctx.block_id)
      local label = spec.label
      if spec.per_dir and cwd then
        label = (label .. " " .. panes.tilde(cwd)):sub(1, 128)
      end
      if block and block.label == label then
        return set_state(layer, "normal", true)
      end
      if layer then
        rex.session.close_layer({ layer_id = layer.layer_id })
      end
      M.open(label, { command = spec.command, cwd = cwd })
    end,
  })
end

M.tool({ action = "lazygit_float", title = "Lazygit", label = "lazygit", command = { "lazygit" }, per_dir = true })
M.tool({ action = "lazydocker_float", title = "Lazydocker", label = "lazydocker", command = { "lazydocker" } })

return M
