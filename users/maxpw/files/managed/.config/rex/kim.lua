local commands = require("commands")
local panes = require("panes")
local popups = require("popups")
local prompts = require("prompts")

local host = "kim"

popups.tool({ action = "kim_top", title = "Kim btop", label = "kim btop", command = { "ssh", "-t", host, "btop" } })

local function remote(method, args)
  local result, err = rex.server(host).call(method, args)
  if err ~= nil then
    error(host .. ": " .. err, 0)
  end
  return result
end

-- The app keeps one connection per server and finds a session only through
-- the server that owns it, so Kim is asked to ask the app.
local function show(ctx, session_id)
  local label = panes.asking_app(ctx).info.label
  local target
  for _, client in ipairs(remote("client.list").clients) do
    local is_app = client.info and client.info.kind == "app"
    if is_app and (target == nil or client.info.label == label) then
      target = client.client_id
    end
  end
  if target == nil then
    error("the Rex app isn't connected to " .. host, 0)
  end
  local args = { session_id = session_id }
  remote("client.perform", { client_id = target, action = "session.select", args = args })
  return args
end

rex.action({
  name = "kim_session",
  title = "Go to Kim Session…",
  description = "Show a session on Kim, creating one when it has none.",
  keywords = "remote host homelab",
  run = function(ctx)
    local sessions = remote("session.list").sessions
    if #sessions == 0 then
      local created = remote("session.create", {
        label = host,
        initial_windows = { { layout = panes.shell_block() } },
      })
      return show(ctx, created.session_id)
    end
    if #sessions == 1 then
      return show(ctx, sessions[1].session_id)
    end
    local items = {}
    for _, session in ipairs(sessions) do
      items[#items + 1] = { id = session.session_id, title = session.label, icon = "server" }
    end
    local session_id = prompts.pick({ title = "Kim sessions", items = items })
    if session_id ~= nil then
      return show(ctx, session_id)
    end
  end,
})

local function dev_session(label, dir, cmd)
  for _, session in ipairs(remote("session.list").sessions) do
    if session.label == label then
      return session.session_id
    end
  end
  -- dir is typed by the person and goes to their own shell, so ~ expands.
  return remote("session.create", {
    label = label,
    initial_windows = {
      {
        layout = rex.layout.horizontal(
          0.5,
          panes.shell_block(nil, { initial_input = "cd " .. dir .. "\n" }),
          panes.shell_block("dev server", {
            command = { "sh", "-c", "cd " .. dir .. " && " .. cmd },
            exit = { on_completion = false },
          })
        ),
      },
    },
  }).session_id
end

rex.action({
  name = "kim_dev",
  title = "Start Dev Server on Kim…",
  description = "Run a project's dev server in a session on Kim and forward its port to this machine.",
  keywords = "remote forward port localhost",
  args = { dir = "string?", cmd = "string?", port = "integer?" },
  run = function(ctx, args)
    local dir = args.dir or prompts.input({ title = "Project directory on Kim", value = "~/" })
    if dir == nil or dir == "" then
      return
    end
    local cmd = args.cmd or prompts.input({ title = "Dev server command", placeholder = "bun dev" })
    if cmd == nil or cmd == "" then
      return
    end
    local port = args.port or tonumber(prompts.input({ title = "Port to forward", placeholder = "3000" }) or "")
    if port == nil then
      return
    end
    if port % 1 ~= 0 or port < 1 or port > 65535 then
      error("port must be a whole number from 1 to 65535", 0)
    end

    local session_id = dev_session("dev " .. (dir:match("[^/]+/?$") or dir):gsub("/$", ""), dir, cmd)
    show(ctx, session_id)

    -- The forward lives in the dev session, so closing that session ends it.
    local forward, err = rex.exec.start({
      "rex",
      "--autostart=false",
      "--server",
      host,
      "forward",
      "new",
      "--session",
      session_id,
      "--local",
      port .. ":localhost:" .. port,
    }, { detach = true, env = commands.env })
    if forward == nil then
      error("forward: " .. err, 0)
    end
    -- It runs until the session closes; exiting at once means it never started
    -- (port taken here, or a server too old to forward).
    local exited = forward:wait(2)
    if exited ~= nil then
      error("forward: " .. exited.stderr, 0)
    end
    return { session_id = session_id, url = "http://localhost:" .. port }
  end,
})
