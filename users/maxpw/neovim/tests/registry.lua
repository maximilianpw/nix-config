-- Every plugin spec module must be registered for exactly one profile, so a new
-- file cannot silently go unloaded (or load in VS Code by accident).
local root = assert(vim.env.NVIM_CONFIG_TEST_ROOT, "NVIM_CONFIG_TEST_ROOT is required")
vim.opt.runtimepath:prepend(root)
local registry = require("config.plugins")

local registered = {}
for _, list in ipairs({ registry.shared, registry.terminal }) do
  for _, module in ipairs(list) do
    assert(not registered[module], "spec module registered twice: " .. module)
    registered[module] = true
  end
end

local plugin_dir = vim.fs.joinpath(root, "lua", "plugins")
for _, path in ipairs(vim.fn.globpath(plugin_dir, "**/*.lua", true, true)) do
  local module = "plugins." .. path:sub(#plugin_dir + 2, -5):gsub("/", ".")
  assert(registered[module], "spec module is not registered in config.plugins: " .. module)
  registered[module] = nil
end
assert(next(registered) == nil, "registered spec module has no file: " .. tostring(next(registered)))

-- lz.n hooks replaced lazy.nvim's loader fields; leftovers would be ignored silently.
for _, module in ipairs(registry.modules(false)) do
  local spec = dofile(vim.fs.joinpath(root, "lua", (module:gsub("%.", "/")) .. ".lua"))
  local list = type(spec[1]) == "table" and spec or { spec }
  for _, s in ipairs(list) do
    for _, field in ipairs({ "config", "init", "dependencies", "cond", "build", "version", "branch", "main" }) do
      assert(s[field] == nil, module .. " still uses lazy.nvim field: " .. field)
    end
    assert(not tostring(s[1]):find("/"), module .. " names a GitHub repo, not a Nix pack directory: " .. s[1])
    local events = type(s.event) == "table" and s.event or { s.event }
    for _, event in ipairs(events) do
      assert(event ~= "VeryLazy", module .. " uses lazy.nvim's VeryLazy event")
    end
  end
end

print("plugin registry checks passed")
