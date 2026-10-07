-- Filesystem helpers shared across formatter / linter / LSP config.
-- Single source of truth for "walk upward looking for a tool config" logic.

local M = {}

--- Walk upward from start_dir looking for any accepted `names`, not crossing above stop_dir.
--- @param names string[] candidate file names
--- @param start_dir string directory to start from
--- @param stop_dir string|nil directory to stop at (inclusive); nil walks to filesystem root
--- @param accept fun(path: string): boolean|nil optional content predicate
--- @return string|nil # path to the first match found, or nil
function M.find_upward_until(names, start_dir, stop_dir, accept)
  local dir = start_dir
  while dir and dir ~= "" do
    for _, name in ipairs(names) do
      local candidate = vim.fs.joinpath(dir, name)
      if vim.uv.fs_stat(candidate) and (not accept or accept(candidate)) then
        return candidate
      end
    end

    if dir == stop_dir then
      break
    end

    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
end

--- Repository root for a directory (VCS-scoped). Used as the ceiling for config lookups:
--- formatter/linter ownership is repository-scoped, so we never walk above the VCS root.
--- @param dir string
--- @return string|nil
function M.project_root(dir)
  return vim.fs.root(dir, { ".git", ".jj" })
end

--- Directory containing the buffer's file.
--- @param bufnr integer
--- @return string
function M.buf_dir(bufnr)
  return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":h")
end

--- True if any of `names` exists from the buffer's directory up to (and including)
--- the project root. Does not walk above the VCS root.
--- @param bufnr integer
--- @param names string[]
--- @param accept fun(path: string): boolean|nil optional content predicate
--- @return boolean
function M.has_config(bufnr, names, accept)
  local dir = M.buf_dir(bufnr)
  local root = M.project_root(dir)
  if not root then
    return false
  end
  return M.find_upward_until(names, dir, root, accept) ~= nil
end

return M
