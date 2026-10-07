-- Plugin spec registry for lz.n. Nix supplies every plugin (see
-- users/maxpw/neovim/plugins.nix); this module only decides what loads, when.
local M = {}

-- Editing primitives shared with VS Code. The reduced VS Code package ships only
-- these plugins, so anything added here must also be added to its Nix profile.
M.shared = {
  "plugins.editor.mini",
  "plugins.editor.flash",
  "plugins.editor.treesitter",
  "plugins.editor.comments",
}

M.terminal = {
  "plugins.ai.amp",
  "plugins.ai.supermaven",
  "plugins.editor.blink",
  "plugins.editor.fff",
  "plugins.editor.grug-far",
  "plugins.editor.obsidian",
  "plugins.editor.render-markdown",
  "plugins.editor.vim-tmux-navigator",
  "plugins.editor.which-key",
  "plugins.git.gitsigns",
  "plugins.lsp.go",
  "plugins.lsp.html",
  "plugins.lsp.init",
  "plugins.lsp.rust",
  "plugins.lsp.typescript",
  "plugins.lsp.typescript-extras",
  "plugins.style.autoformat",
  "plugins.style.lint",
  "plugins.testing.debug",
  "plugins.testing.neotest",
  "plugins.ui.bufferline",
  "plugins.ui.colorscheme",
  "plugins.ui.lualine",
  "plugins.ui.neo-tree",
  "plugins.ui.noice",
  "plugins.ui.snacks",
}

function M.is_vscode()
  return vim.g.vscode ~= nil or vim.g.maxpw_nvim_profile == "vscode"
end

function M.modules(vscode)
  local modules = vim.list_slice(M.shared)
  if not vscode then
    vim.list_extend(modules, M.terminal)
  end
  return modules
end

function M.specs(vscode)
  return vim.tbl_map(require, M.modules(vscode))
end

-- Add plugins that have no spec of their own (libraries and extensions that
-- lazy.nvim used to load as `dependencies`). Nix keeps them in pack/*/opt.
function M.packadd(...)
  for _, name in ipairs({ ... }) do
    vim.cmd.packadd(name)
  end
end

-- Load plugins that do have specs, running their before/after hooks.
function M.trigger(...)
  require("lz.n").trigger_load({ ... })
end

function M.setup()
  require("lz.n").load(M.specs(M.is_vscode()))
end

return M
