-- vscode-neovim integration
-- Loaded only when running inside VS Code / Cursor via the vscode-neovim extension.
-- Mirrors familiar terminal-nvim keymaps onto VS Code commands so muscle memory carries over.
-- Keep the lhs/desc here in sync with the native equivalents in lua/plugins/lsp/init.lua
-- and lua/config/keymaps.lua.

if not vim.g.vscode then
  return
end

local ok, vscode = pcall(require, "vscode")
if not ok then
  return
end

local function action(name, opts)
  return function()
    vscode.action(name, opts)
  end
end

local map = function(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true })
end

-- ───────── Find / search (mirrors fff.nvim leader keys) ─────────
map("n", "<leader>ff", action("workbench.action.quickOpen"), "Find Files")
map("n", "<leader>fg", action("workbench.action.quickOpen"), "Find in Git Root")
map("n", "<leader>fl", action("workbench.action.findInFiles"), "Find by Grep")
map("n", "<leader>fb", action("workbench.action.showAllEditors"), "Find Buffers")
map("n", "<leader>fr", action("workbench.action.openRecent"), "Recent Files")
map("n", "<leader>fs", action("workbench.action.gotoSymbol"), "Find Symbols")
map("n", "<leader>fc", function()
  vscode.action("workbench.action.quickOpen", { args = { require("util.source").editable_config_dir() .. "/" } })
end, "Find Config Files (editable source)")
map("n", "<leader>fw", function()
  vscode.action("workbench.action.findInFiles", {
    args = { query = vim.fn.expand("<cword>") },
  })
end, "Find Word Under Cursor")
map("v", "<leader>fw", function()
  vim.cmd('normal! "vy')
  vscode.action("workbench.action.findInFiles", {
    args = { query = vim.fn.getreg("v") },
  })
end, "Find Selection")

-- ───────── LSP (the <leader>c group) ─────────
map("n", "gd", action("editor.action.revealDefinition"), "Goto Definition")
map("n", "gD", action("editor.action.revealDeclaration"), "Goto Declaration")
map("n", "gI", action("editor.action.goToImplementation"), "Goto Implementation")
map("n", "gt", action("editor.action.goToTypeDefinition"), "Goto Type Definition")
map("n", "gr", action("editor.action.goToReferences"), "Goto References")
map("n", "K", action("editor.action.showHover"), "Hover Documentation")
map("n", "<leader>ca", action("editor.action.quickFix"), "Code Action")
map("n", "<leader>cr", action("editor.action.rename"), "Rename")
map("n", "<leader>cf", action("editor.action.formatDocument"), "Format Document")
map("v", "<leader>cf", action("editor.action.formatSelection"), "Format Selection")
map("n", "<leader>co", action("editor.action.organizeImports"), "Organize Imports")
map("n", "<leader>cs", action("editor.action.triggerParameterHints"), "Signature Documentation")
map("n", "<leader>cS", action("workbench.action.showAllSymbols"), "Workspace Symbols")

-- ───────── Diagnostics ─────────
map("n", "[d", action("editor.action.marker.prev"), "Previous Diagnostic")
map("n", "]d", action("editor.action.marker.next"), "Next Diagnostic")
map("n", "<leader>xx", action("workbench.actions.view.problems"), "Problems")
map("n", "<leader>xX", action("workbench.actions.view.problems"), "Problems")

-- ───────── Window navigation ─────────
map("n", "<C-h>", action("workbench.action.focusLeftGroup"), "Focus Left")
map("n", "<C-j>", action("workbench.action.focusBelowGroup"), "Focus Below")
map("n", "<C-k>", action("workbench.action.focusAboveGroup"), "Focus Above")
map("n", "<C-l>", action("workbench.action.focusRightGroup"), "Focus Right")
map("n", "<leader>-", action("workbench.action.splitEditorDown"), "Split Below")
map("n", "<leader>|", action("workbench.action.splitEditor"), "Split Right")

-- ───────── Buffers / tabs ─────────
map("n", "<S-h>", action("workbench.action.previousEditor"), "Previous Tab")
map("n", "<S-l>", action("workbench.action.nextEditor"), "Next Tab")
map("n", "<leader>bd", action("workbench.action.closeActiveEditor"), "Close Buffer")
map("n", "<leader>bD", action("workbench.action.closeOtherEditors"), "Close Other Buffers")

-- ───────── Explorer / sidebar ─────────
map("n", "<leader>e", action("workbench.view.explorer"), "Explorer")
map("n", "<leader>E", action("workbench.action.toggleSidebarVisibility"), "Toggle Sidebar")

-- ───────── Git ─────────
map("n", "<leader>gg", action("workbench.view.scm"), "Source Control")
map("n", "<leader>gb", action("gitlens.toggleFileBlame"), "Toggle Blame")
map("n", "<leader>gd", action("git.openChange"), "Diff Current File")

-- ───────── Terminal ─────────
map("n", "<leader>tt", action("workbench.action.terminal.toggleTerminal"), "Toggle Terminal")

-- ───────── Misc ─────────
map("n", "<leader>?", action("workbench.action.showCommands"), "Command Palette")
map("n", "<leader>w", action("workbench.action.files.save"), "Save")
