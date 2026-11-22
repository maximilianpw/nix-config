-- Labels each terminal "<repository> · <branch>" as its directory or branch
-- changes. Run with `rex do pane-labels.lua --all git=<path> jj=<path>`.
--
-- The script owns a label only while it is Rex's default or carries the
-- separator, so a pane someone named, and a pane an action labelled as its
-- identity (the tool popups), is never renamed.
local terminal = "com.superlogical.terminal"
local default_label = "shell"
local separator = " · "

local git = assert(rex.args.git, "git=<path> is required")
local jj = assert(rex.args.jj, "jj=<path> is required")

local function repository_label(cwd)
  local head = rex.exec({ git, "-C", cwd, "rev-parse", "--show-toplevel", "--abbrev-ref", "HEAD" })
  local root, ref = (head and head.ok and head.stdout or ""):match("^([^\n]+)\n([^\n]+)")
  if root == nil then
    return default_label
  end
  -- A colocated jj checkout keeps Git's HEAD detached; its bookmark or
  -- change is the name people know it by.
  if ref == "HEAD" then
    local change = rex.exec({
      jj,
      "log",
      "--repository",
      root,
      "--ignore-working-copy",
      "--no-graph",
      "--revisions",
      "@",
      "--template",
      'if(bookmarks, bookmarks.join(" "), change_id.shortest(8))',
    })
    if change and change.ok and change.stdout ~= "" then
      ref = change.stdout
    else
      local commit = rex.exec({ git, "-C", cwd, "rev-parse", "--short", "HEAD" })
      ref = commit and commit.stdout:match("[^\n]+") or ref
    end
  end
  return root:match("[^/]+$") .. separator .. ref
end

local function relabel(session_id, block_id)
  local described = rex.call("session.describe_block", { session_id = session_id, block_id = block_id })
  local current = described and described.block.label
  if current ~= default_label and not (current and current:find(separator, 1, true)) then
    return
  end
  local process = rex.block.call(terminal, "process", { session_id = session_id, block_id = block_id })
  local cwd = process and process.foreground and process.foreground.cwd
  local label = cwd and repository_label(cwd) or default_label
  if label ~= current and #label <= 128 then
    rex.call("session.set_block_label", { session_id = session_id, block_id = block_id, label = label })
  end
end

-- A command start and end, and a cd, each fire within the same moment;
-- one relabel after the burst is enough.
local pending = {}

local function schedule(ctx)
  local session_id, block_id = ctx.session_id, ctx.block_id
  if pending[block_id] then
    pending[block_id]:cancel()
  end
  pending[block_id] = rex.after(0.3, function()
    pending[block_id] = nil
    relabel(session_id, block_id)
  end)
end

rex.on("terminal.pwd_changed", schedule)
-- The foreground returns to the shell after every command, which is when a
-- `git switch` or `jj new` has changed the branch without changing directory.
rex.on("terminal.process_changed", schedule)
