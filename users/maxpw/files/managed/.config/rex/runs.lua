local panes = require("panes")
local prompts = require("prompts")

local label_prefix = "run "

-- Wrapped around the command: a failure makes its pane fill the window, a
-- pass leaves the layout alone. The subshell keeps a command's own `exit`
-- from skipping the check.
local function zoom_on_failure(cmd)
  return "(\n" .. cmd .. '\n)\ncode=$?\n[ "$code" -eq 0 ] || rex zoom "$REX_BLOCK" --on\nexit "$code"'
end

local last_command = {}

local function close_previous_run(session_id)
  local view = rex.session.view({})
  local window = view and panes.active_window(view)
  if window == nil then
    return
  end
  panes.each_block({ windows = { window } }, function(block)
    if (block.label or ""):sub(1, #label_prefix) == label_prefix then
      rex.call("block.close", { session_id = session_id, block_id = block.block_id })
    end
  end)
end

rex.action({
  name = "run_split",
  title = "Run Command in Split…",
  description = "Run a command beside the focused pane; the pane zooms if the command fails.",
  keywords = "test build make",
  args = { cmd = "string?" },
  run = function(ctx, args)
    local cmd = args.cmd
      or prompts.input({
        title = "Run in split",
        placeholder = "make test",
        value = last_command[ctx.session_id],
        confirm = "Run",
      })
    if cmd == nil or cmd == "" then
      return
    end
    last_command[ctx.session_id] = cmd

    local cwd = panes.cwd(ctx.block_id)
    close_previous_run(ctx.session_id)
    local split, err = rex.session.new_split({
      anchor_id = ctx.block_id,
      direction = "horizontal",
      side = "after",
      focus = false,
      layout = panes.shell_block((label_prefix .. cmd):sub(1, 128), {
        cwd = cwd,
        command = { "sh", "-c", zoom_on_failure(cmd) },
        exit = { on_completion = false },
      }),
    })
    if err ~= nil then
      error(err, 0)
    end
    return { block_id = split.block_ids[1] }
  end,
})
