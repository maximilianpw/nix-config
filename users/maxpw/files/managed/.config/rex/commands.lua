local M = {}

-- The server inherits launchd's bare PATH; everything these actions run
-- (zoxide, workspaces, rex, ssh) comes from the Nix profiles.
M.env = {
  PATH = "/etc/profiles/per-user/"
    .. (os.getenv("USER") or "")
    .. "/bin:/run/current-system/sw/bin:"
    .. (os.getenv("PATH") or ""),
}

function M.run(argv, opts)
  opts = opts or {}
  opts.env = M.env
  local result, err = rex.exec(argv, opts)
  if result == nil then
    error(argv[1] .. ": " .. err, 0)
  end
  return result
end

function M.output(argv, opts)
  local result = M.run(argv, opts)
  if not result.ok then
    error(result.stderr ~= "" and result.stderr or argv[1] .. ": exit " .. result.code, 0)
  end
  return result.stdout
end

return M
