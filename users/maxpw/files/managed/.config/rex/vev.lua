local commands = require("commands")
local panes = require("panes")
local prompts = require("prompts")

local root = (os.getenv("HOME") or "") .. "/Local/vev"
local compose_dir = root .. "/vev-docker-compose"
local dashboard_dir = compose_dir .. "/submodules/vev-dashboard"
local ai_core_dir = root .. "/ai-core"
local label = "vev"

-- Each command is typed into a shell rather than run as the pane's program,
-- so Ctrl-C leaves a prompt where it can be started again. dcompose
-- (modules/custom-scripts) adds the NODE_AUTH_TOKEN the image builds need.
local function shell(name, dir, input)
  return panes.shell_block(name, { cwd = dir, initial_input = input .. "\n" })
end

-- ai-core joins the external vev-server network the main stack creates, and
-- `down` removes it, so wait for it rather than lose a race at startup. The
-- pane's shell may be fish, so the loop runs in sh.
local ai_core_up = "sh -c 'until docker network inspect vev-server >/dev/null 2>&1; do sleep 2; done' && dcompose up"

local function existing_session()
  for _, session in ipairs(rex.call("session.list").sessions) do
    if session.label == label then
      return session.session_id
    end
  end
end

local function create_session(with_ai_core)
  local dirs = { compose_dir, dashboard_dir }
  if with_ai_core then
    dirs[#dirs + 1] = ai_core_dir
  end
  for _, dir in ipairs(dirs) do
    if not commands.run({ "test", "-d", dir }).ok then
      error(dir .. " does not exist", 0)
    end
  end

  local right = shell("dashboard", dashboard_dir, "npm run start")
  if with_ai_core then
    right = rex.layout.vertical(0.5, right, shell("ai-core", ai_core_dir, ai_core_up))
  end
  local created, err = rex.call("session.create", {
    label = label,
    initial_windows = {
      {
        window_label = "stack",
        layout = rex.layout.horizontal(0.5, shell("docker", compose_dir, "dcompose up --build"), right),
      },
    },
  })
  if err ~= nil then
    error(err, 0)
  end
  return created.session_id
end

rex.action({
  name = "vev_up",
  title = "Start VEV Stack…",
  description = "Open a session running vev-docker-compose and the dashboard, optionally with ai-core.",
  keywords = "docker compose dashboard ai-core work",
  args = { ai_core = "boolean?" },
  run = function(ctx, args)
    -- The stack owns fixed ports, so a running session is shown, not doubled.
    local session_id = existing_session()
    if session_id == nil then
      local with_ai_core = args.ai_core
      if with_ai_core == nil then
        local choice = prompts.pick({
          title = "Start VEV stack",
          items = {
            { id = "stack", title = "Docker compose + dashboard", icon = "package" },
            { id = "ai-core", title = "Docker compose + dashboard + ai-core", icon = "star" },
          },
        })
        if choice == nil then
          return
        end
        with_ai_core = choice == "ai-core"
      end
      session_id = create_session(with_ai_core)
    end
    return panes.show_session(ctx, session_id)
  end,
})
