-- Exercise real provider construction before any Lua buffer loads LazyDev.
-- Run in a fresh terminal editor: prior plugin tests may already load it.
assert(package.loaded.lazydev == nil, "LazyDev loaded before the completion regression")
vim.api.nvim_exec_autocmds("InsertEnter", { buffer = 0 })
local sources = require("blink.cmp.sources.lib")

local function check_providers(expect_lazydev)
  local providers = sources.get_enabled_providers("default")
  assert(
    vim.tbl_contains(sources.get_enabled_provider_ids("default"), "lazydev") == expect_lazydev,
    "LazyDev provider has the wrong filetype scope"
  )
  if expect_lazydev then
    assert(package.loaded["lazydev.integrations.blink"], "LazyDev provider was not constructed")
  end
  assert(providers.path and providers.snippets, "Core completion providers are missing")
  sources.get_signature_help_trigger_characters()
end

check_providers(false)
vim.bo.filetype = "text"
check_providers(false)
assert(package.loaded.lazydev == nil, "Non-Lua completion loaded LazyDev")

vim.bo.filetype = "lua"
check_providers(true)
assert(package.loaded.lazydev ~= nil, "Lua filetype did not load LazyDev")

vim.bo.filetype = "text"
check_providers(false)
vim.b.bigfile = true
vim.b.bigfile_level = "max_ts"
assert(sources.get_enabled_providers("default").buffer == nil, "Large buffer completion guard was lost")
print("completion provider contracts passed")
