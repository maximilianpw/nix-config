-- Every enabled server resolves to a startable config, and after/lsp/ overrides
-- beat nvim-lspconfig's defaults (lsp/<name>.lua files merge with later ones winning).
require("config.plugins").trigger("nvim-lspconfig")

for name in vim.gsplit(assert(vim.env.LSP_SERVERS), "\n", { trimempty = true }) do
  local config = vim.lsp.config[name]
  assert(config and config.cmd, "enabled server has no config with a cmd: " .. name)
end

local eslint = vim.lsp.config.eslint
assert(eslint.settings.format == false, "nvim-lspconfig overrode after/lsp/eslint.lua")
assert(type(eslint.root_dir) == "function", "nvim-lspconfig's ESLint base config is missing")
assert(vim.lsp.config.lua_ls.settings.Lua.workspace.library == nil, "lua_ls indexes the whole runtimepath")
