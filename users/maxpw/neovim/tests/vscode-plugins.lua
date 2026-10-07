-- Integration test for the reduced VS Code package. tests/run.sh launches it the
-- way vscode-neovim does: `--cmd "source <runtime>/vscode-neovim.vim"` from a
-- stand-in extension runtime, so vim.g.vscode is set before init and the
-- extension's `vscode` modules are only reachable through the runtimepath.
assert(vim.g.maxpw_nvim_profile == "vscode", "not running the VS Code package")
assert(vim.g.vscode, "extension bootstrap did not run before init")
local runtime = assert(vim.g.vscode_neovim_runtime, "extension runtime was not announced")
assert(vim.tbl_contains(vim.api.nvim_list_runtime_paths(), runtime), "extension runtime was removed from the runtimepath")
assert(require("vscode.internal").from_extension_runtime, "vscode.internal did not resolve from the extension runtime")
local actions = _G.vscode_test_actions

-- The registry selects only the shared editing primitives.
local registry = require("config.plugins")
assert(registry.is_vscode(), "vim.g.vscode did not select the VS Code profile")
local specs = {}
for _, spec in ipairs(registry.specs(true)) do
  for _, s in ipairs(type(spec[1]) == "table" and spec or { spec }) do
    specs[s[1]] = true
  end
end
for _, name in ipairs({ "mini.nvim", "flash.nvim", "nvim-treesitter", "ts-comments.nvim" }) do
  assert(specs[name], "VS Code editing primitive excluded: " .. name)
end

-- The package ships nothing else.
local allowed = {
  ["lz.n"] = true,
  -- Nixvim's generated runtime files (ftplugin/after hooks); no plugin code.
  ["nvim-config"] = true,
  ["mini.nvim"] = true,
  ["flash.nvim"] = true,
  ["nvim-treesitter"] = true,
  ["nvim-treesitter-textobjects"] = true,
  ["ts-comments.nvim"] = true,
}
for _, dir in ipairs(vim.fn.globpath(vim.o.packpath, "pack/*/*/*", false, true)) do
  local name = vim.fs.basename(dir)
  -- Neovim's own optional packages (pack/dist/opt) ship with $VIMRUNTIME.
  local builtin = vim.startswith(dir, vim.env.VIMRUNTIME)
  -- Nixvim merges the grammar and query plugins into one parser/queries tree.
  local treesitter_runtime = name == "nvim-treesitter-grammars"
  assert(builtin or allowed[name] or treesitter_runtime, "terminal plugin shipped in the VS Code package: " .. name)
end

local function assert_bridges()
  for key, action in pairs({
    gd = "editor.action.revealDefinition",
    ["<leader>cf"] = "editor.action.formatDocument",
    ["<leader>ff"] = "workbench.action.quickOpen",
    ["<leader>e"] = "workbench.view.explorer",
    ["<C-h>"] = "workbench.action.focusLeftGroup",
  }) do
    vim.fn.maparg(key, "n", false, true).callback()
    assert(actions[#actions] == action, "plugin overwrote bridge: " .. key)
  end
end

require("lz.n").trigger_load({ "mini.nvim", "flash.nvim", "nvim-treesitter", "ts-comments.nvim" })
vim.bo.filetype = "typescript"
for _, event in ipairs({ "InsertEnter", "LspAttach" }) do
  vim.api.nvim_exec_autocmds(event, { buffer = 0 })
end
vim.api.nvim_exec_autocmds("User", { pattern = "DeferredUIEnter" })
assert_bridges()

-- mini.nvim sets up only its editing modules here; sessions and trailspace are terminal-only.
for _, module in ipairs({ "mini.ai", "mini.move", "mini.surround", "mini.pairs", "mini.splitjoin", "mini.align" }) do
  assert(package.loaded[module], "VS Code is missing editing primitive: " .. module)
end
for _, module in ipairs({ "mini.trailspace", "mini.sessions", "mini.hipatterns" }) do
  assert(package.loaded[module] == nil, "VS Code loaded terminal-only module: " .. module)
end
assert(vim.fn.maparg("<leader>qs", "n") == "", "VS Code mini spec includes terminal session keys")

for _, module in ipairs({ "snacks", "blink.cmp", "supermaven-nvim", "lspconfig", "conform", "dap" }) do
  assert(package.loaded[module] == nil, "terminal module loaded in VS Code: " .. module)
end
assert(#vim.lsp.get_clients() == 0, "VS Code started a terminal language server")
print("real VS Code package boundary passed")
