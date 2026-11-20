-- Plugin spec registry for lz.n. Nix supplies every plugin (see
-- users/maxpw/neovim/plugins.nix); this module only decides what loads, when.
local M = {}

M.modules = {
  "plugins.editor.blink",
  "plugins.editor.comments",
  "plugins.editor.fff",
  "plugins.editor.flash",
  "plugins.editor.mini",
  "plugins.editor.oil",
  "plugins.editor.quicker",
  "plugins.editor.render-markdown",
  "plugins.editor.todo-comments",
  "plugins.editor.treesitter",
  "plugins.editor.treesitter-context",
  "plugins.editor.vim-tmux-navigator",
  "plugins.editor.which-key",
  "plugins.git.codediff",
  "plugins.git.gitsigns",
  "plugins.lsp.html",
  "plugins.lsp.init",
  "plugins.lsp.rust",
  "plugins.lsp.typescript",
  "plugins.lsp.typescript-extras",
  "plugins.style.autoformat",
  "plugins.style.lint",
  "plugins.ui.bufferline",
  "plugins.ui.colorscheme",
  "plugins.ui.lualine",
  "plugins.ui.neo-tree",
  "plugins.ui.noice",
  "plugins.ui.snacks",
}

function M.specs()
  return vim.tbl_map(require, M.modules)
end

-- Add plugins that have no spec of their own (libraries and extensions that
-- other plugins need). Nix keeps them in pack/*/opt.
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
  require("lz.n").load(M.specs())
end

return M
