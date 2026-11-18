-- Run by herdr-bridge.sh with `rex do`. Prints every terminal on this server
-- in the shape herdr-jj reads from `herdr pane list`. A terminal whose
-- directory is unknown is listed without one, which makes herdr-jj refuse to
-- archive rather than assume the checkout is free.
local terminal = "com.superlogical.terminal"

local function view_of(session_id)
  local view = rex.call("session.view", { session_id = session_id })
  if view == nil then
    rex.session.attach({ session_id = session_id })
    view = assert(rex.call("session.view", { session_id = session_id }))
  end
  return view
end

local listed = {}
for _, session in ipairs(assert(rex.call("session.list")).sessions) do
  for _, window in ipairs(view_of(session.session_id).windows) do
    for _, layer in ipairs(window.layers) do
      for _, block in ipairs(layer.blocks) do
        if block.creator_name == terminal then
          local proc = rex.block.call(terminal, "process", {
            session_id = session.session_id,
            block_id = block.block_id,
          })
          listed[#listed + 1] = {
            pane_id = block.block_id,
            workspace_id = session.session_id,
            cwd = proc and proc.foreground and proc.foreground.cwd,
          }
        end
      end
    end
  end
end

-- An empty Lua table encodes as an object; herdr-jj requires an array.
local panes = #listed == 0 and "[]" or assert(rex.json.encode(listed))
io.write('{"result":{"panes":', panes, "}}\n")
