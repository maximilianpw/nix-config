local root = assert(vim.env.NVIM_CONFIG_TEST_ROOT, "NVIM_CONFIG_TEST_ROOT is required")
vim.opt.runtimepath:prepend(root)

-- Resolve symlinked temp roots (macOS /var -> /private/var) so paths compare
-- equal to the names Neovim gives buffers.
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, "p")
temp = vim.uv.fs_realpath(temp)

local function cleanup()
  vim.fn.delete(temp, "rf")
end

local function fail(message)
  cleanup()
  error(message)
end

local function expect(condition, message)
  if not condition then
    fail(message)
  end
end

local function write(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ contents }, path, "b")
end

local function buffer_for(path)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, path)
  return bufnr
end

-- Bigfile classification must exist by the time later BufReadPre consumers run.
dofile(vim.fs.joinpath(root, "lua", "config", "bigfile.lua"))
local observed = {}
vim.api.nvim_create_autocmd("BufReadPre", {
  callback = function(event)
    observed[vim.api.nvim_buf_get_name(event.buf)] = vim.b[event.buf].bigfile_level or "small"
  end,
})

local thresholds = {
  { name = "large-equal", size = vim.g.bigfile.large, want = "small" },
  { name = "large", size = vim.g.bigfile.large + 1, want = "large" },
  { name = "max-ts-equal", size = vim.g.bigfile.max_ts, want = "large" },
  { name = "max-ts", size = vim.g.bigfile.max_ts + 1, want = "max_ts" },
  { name = "huge-equal", size = vim.g.bigfile.huge, want = "max_ts" },
  { name = "huge", size = vim.g.bigfile.huge + 1, want = "huge" },
}

for _, case in ipairs(thresholds) do
  local path = vim.fs.joinpath(temp, case.name .. ".txt")
  write(path, string.rep("x", case.size))
  vim.cmd.edit(vim.fn.fnameescape(path))
  expect(observed[path] == case.want, case.name .. " was not classified during BufReadPre")
  expect((vim.b.bigfile_level or "small") == case.want, case.name .. " had the wrong final tier")
end

local reread = vim.fs.joinpath(temp, "reread.txt")
write(reread, string.rep("x", vim.g.bigfile.huge + 1))
vim.cmd.edit(vim.fn.fnameescape(reread))
expect(vim.b.bigfile_level == "huge", "huge reread fixture was not classified")
write(reread, "small")
vim.cmd.edit({ bang = true })
expect(vim.b.bigfile == false and vim.b.bigfile_level == nil, "reread retained stale bigfile state")

vim.b.bigfile = true
vim.b.bigfile_level = "huge"
vim.bo.buftype = "nofile"
vim.api.nvim_exec_autocmds("BufReadPre", { buffer = 0 })
expect(vim.b.bigfile == false and vim.b.bigfile_level == nil, "special buffer retained stale bigfile state")

-- Prettier ownership must be content-aware and stop at the current VCS root.
local tooling = require("util.tooling")
local function has_prettier(path)
  return tooling.has_prettier_config(buffer_for(path))
end

local cases = {
  { name = "object", json = '{"prettier":{}}', want = true },
  { name = "string", json = '{"prettier":"@example/prettier-config"}', want = true },
  { name = "absent", json = '{"scripts":{"prettier":"prettier ."}}', want = false },
  { name = "null", json = '{"prettier":null}', want = false },
  { name = "false", json = '{"prettier":false}', want = false },
  { name = "number", json = '{"prettier":1}', want = false },
  { name = "list", json = '{"prettier":[]}', want = false },
  { name = "invalid", json = '{"prettier":', want = false },
}

for _, case in ipairs(cases) do
  local repo = vim.fs.joinpath(temp, "package-" .. case.name)
  vim.fn.mkdir(vim.fs.joinpath(repo, ".git"), "p")
  write(vim.fs.joinpath(repo, "package.json"), case.json)
  expect(has_prettier(vim.fs.joinpath(repo, "src", "index.ts")) == case.want, case.name .. " package.json")
end

local ancestor = vim.fs.joinpath(temp, "ancestor")
vim.fn.mkdir(vim.fs.joinpath(ancestor, ".git"), "p")
write(vim.fs.joinpath(ancestor, "package.json"), '{"prettier":{}}')
write(vim.fs.joinpath(ancestor, "packages", "app", "package.json"), '{"private":true}')
expect(has_prettier(vim.fs.joinpath(ancestor, "packages", "app", "src", "index.ts")), "ancestor config hidden")

local worktree = vim.fs.joinpath(temp, "worktree")
write(vim.fs.joinpath(worktree, ".git"), "gitdir: /tmp/example")
write(vim.fs.joinpath(worktree, "package.json"), '{"prettier":{}}')
expect(has_prettier(vim.fs.joinpath(worktree, "index.ts")), ".git file root was not recognized")

local jj = vim.fs.joinpath(temp, "jj")
vim.fn.mkdir(vim.fs.joinpath(jj, ".jj"), "p")
write(vim.fs.joinpath(jj, "package.json"), '{"prettier":{}}')
expect(has_prettier(vim.fs.joinpath(jj, "index.ts")), ".jj root was not recognized")

local nested = vim.fs.joinpath(temp, "nested")
vim.fn.mkdir(vim.fs.joinpath(nested, ".git"), "p")
write(vim.fs.joinpath(nested, ".prettierrc"), "{}")
vim.fn.mkdir(vim.fs.joinpath(nested, "child", ".git"), "p")
expect(not has_prettier(vim.fs.joinpath(nested, "child", "index.ts")), "search crossed nested VCS root")

local no_vcs = vim.fs.joinpath(temp, "no-vcs")
write(vim.fs.joinpath(no_vcs, "package.json"), '{"prettier":{}}')
expect(not has_prettier(vim.fs.joinpath(no_vcs, "index.ts")), "config outside a VCS root was accepted")

cleanup()
print("architecture checks passed")
