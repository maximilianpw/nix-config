local M = {}

M.terminal = "com.superlogical.terminal"

local home = os.getenv("HOME") or ""

function M.shell_block(label, options)
  return rex.layout.block({ flavor = M.terminal .. ".shell", label = label, options = options })
end

function M.foreground(block_id, session_id)
  local proc = block_id
    and rex.block.call(M.terminal, "process", { session_id = session_id, block_id = block_id })
  return proc and proc.foreground
end

function M.cwd(block_id, session_id)
  local fg = M.foreground(block_id, session_id)
  return fg and fg.cwd
end

function M.focused_cwd(ctx)
  local cwd = M.cwd(ctx.block_id)
  if cwd == nil then
    error("focus a terminal first", 0)
  end
  return cwd
end

-- An action reads only the session it runs in until it attaches to another.
function M.view(session_id)
  local view = rex.call("session.view", { session_id = session_id })
  if view == nil then
    rex.call("session.attach", { session_id = session_id })
    view = rex.call("session.view", { session_id = session_id })
  end
  return view
end

function M.each_block(view, visit)
  for _, window in ipairs(view.windows) do
    for _, layer in ipairs(window.layers) do
      for _, block in ipairs(layer.blocks) do
        visit(block, layer, window)
      end
    end
  end
end

function M.active_window(view)
  for _, window in ipairs(view.windows) do
    if window.window_id == view.active_window_id then
      return window
    end
  end
end

-- The app a request came from: the caller itself for a key or the palette,
-- and for a command run in a pane (a CLI client) the app that owns the pane.
function M.asking_app(ctx)
  local described = ctx.block_id and rex.session.describe_block({ block_id = ctx.block_id })
  local owner = described and described.block.owner
  for _, client in ipairs(rex.call("client.list").clients) do
    local is_app = client.info and client.info.kind == "app"
    if is_app and (client.client_id == ctx.client_id or client.client_id == owner) then
      return client
    end
  end
  error("no Rex app owns this pane, so nothing can show the session", 0)
end

function M.show_session(ctx, session_id)
  local app = M.asking_app(ctx)
  local args = { session_id = session_id }
  if app.client_id == ctx.client_id then
    rex.client.queue("session.select", args)
  else
    local _, err = rex.call("client.perform", { client_id = app.client_id, action = "session.select", args = args })
    if err ~= nil then
      error(err, 0)
    end
  end
  return args
end

function M.tilde(path)
  if home ~= "" and (path == home or path:sub(1, #home + 1) == home .. "/") then
    return "~" .. path:sub(#home + 1)
  end
  return path
end

return M
