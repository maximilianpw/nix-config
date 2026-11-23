local commands = require("commands")
local panes = require("panes")
local popups = require("popups")
local prompts = require("prompts")

-- A project's session is the one with a terminal in its directory. Labels
-- can't identify it: agents rename their session after the task at hand.
local function session_in(dir)
  local inside
  for _, session in ipairs(rex.call("session.list").sessions) do
    local view = panes.view(session.session_id)
    if view then
      local exact = false
      panes.each_block(view, function(block)
        if block.creator_name == panes.terminal then
          local cwd = panes.cwd(block.block_id, session.session_id)
          exact = exact or cwd == dir
          if cwd and cwd:sub(1, #dir + 1) == dir .. "/" then
            inside = inside or session.session_id
          end
        end
      end)
      if exact then
        return session.session_id
      end
    end
  end
  return inside
end

local function open(ctx, dir)
  -- Terminals report physical directories; zoxide and people give logical ones.
  dir = commands.output({ "realpath", dir }):match("[^\n]+")
  local session_id = session_in(dir)
  if session_id == nil then
    local created, err = rex.call("session.create", {
      label = dir:match("[^/]+$") or dir,
      initial_windows = {
        {
          layout = rex.layout.horizontal(
            0.6,
            panes.shell_block(nil, { cwd = dir, initial_input = "nvim\n" }),
            panes.shell_block(nil, { cwd = dir })
          ),
        },
      },
    })
    if err ~= nil then
      error(err, 0)
    end
    session_id = created.session_id
  end
  return panes.show_session(ctx, session_id)
end

local function recent_directories()
  local items = {}
  for dir in commands.output({ "zoxide", "query", "--list" }):gmatch("[^\n]+") do
    if #items == 500 then
      break
    end
    items[#items + 1] = { id = dir, title = dir:match("[^/]+$") or dir, subtitle = panes.tilde(dir), icon = "folder" }
  end
  return items
end

rex.action({
  name = "project_open",
  title = "Open Project…",
  description = "Switch to the session working in a directory, or create one.",
  keywords = "zoxide session switch",
  args = { dir = "string?" },
  run = function(ctx, args)
    local dir = args.dir
      or prompts.pick({ title = "Open project", placeholder = "Filter directories", items = recent_directories() })
    if dir == nil then
      return
    end
    return open(ctx, dir)
  end,
})

-- `workspaces` (packages/workspaces) creates and lists JJ and Git checkouts
-- and opens each one through project_open. It keeps its journals in
-- ~/.local/state/workspaces.
local function create_workspace(dir, name)
  local result = commands.run({ "workspaces", "create", name, "--no-open", "--repo", dir })
  local reply = rex.json.decode(result.ok and result.stdout or result.stderr)
  if result.ok and reply and reply.ok then
    return reply.result.workspace
  end
  return nil, reply and reply.error and reply.error.message or result.stderr
end

-- The picker runs in a popup terminal; what it opens or creates comes back
-- through `rex do project_open`.
local function workspace_action(name, title, picker)
  rex.action({
    name = "workspace_" .. name,
    title = title,
    keywords = "jj git worktree",
    run = function(ctx)
      local dir = panes.focused_cwd(ctx)
      local command = { "workspaces", "pick", picker, "--repo", dir }
      popups.open("workspace " .. name, { cwd = dir, command = command }, { 0.15, 0.15, 0.7, 0.7 })
    end,
  })
end

workspace_action("open", "Open Workspace (JJ or Git)…", "open")
workspace_action("new", "New Workspace (JJ or Git)…", "create")
workspace_action("archive", "Archive JJ Workspace (Keep Files)…", "cleanup")

rex.action({
  name = "agents_fanout",
  title = "Fan Out Agents into New Workspaces…",
  description = "Create a workspace per name and start an agent on the same task in each, one tab apiece.",
  keywords = "claude parallel worktree",
  args = { names = "string?", task = "string?", agent = "string?" },
  run = function(ctx, args)
    local dir = panes.focused_cwd(ctx)
    local names = args.names
      or prompts.input({ title = "Workspaces to create", placeholder = "Names separated by spaces" })
    if names == nil then
      return
    end
    local task = args.task
      or prompts.input({ title = "Task for each agent", placeholder = "Leave empty to start them idle" })
    if task == nil then
      return
    end

    local command = { args.agent or "claude" }
    if task ~= "" then
      command[2] = task
    end
    local started = {}
    for name in names:gmatch("%S+") do
      local workspace, err = create_workspace(dir, name)
      if workspace then
        _, err = rex.session.new_window({
          window_label = name,
          focus = false,
          layout = panes.shell_block(name, { cwd = workspace.path, command = command }),
        })
      end
      if err ~= nil then
        error(name .. ": " .. err .. " (already started: " .. table.concat(started, " ") .. ")", 0)
      end
      started[#started + 1] = name
    end
    return { started = started }
  end,
})
