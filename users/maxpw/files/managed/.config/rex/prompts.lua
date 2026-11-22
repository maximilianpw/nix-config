local M = {}

-- nil means the person closed the prompt. Every other way a prompt ends
-- without an answer (no app connected, a server older than its app) is raised
-- so the action reports it instead of silently doing nothing.
local function answer(value, why, detail)
  if value ~= nil or why == "cancelled" then
    return value
  end
  error("prompt " .. why .. (detail and ": " .. detail or ""), 0)
end

function M.input(spec)
  return answer(rex.ui.input(spec))
end

function M.pick(spec)
  return answer(rex.ui.pick(spec))
end

return M
