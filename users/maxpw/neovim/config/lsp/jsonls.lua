-- Schemas are injected dynamically via vim.lsp.config in lsp/init.lua
return {
  cmd = { "vscode-json-language-server", "--stdio" },
  filetypes = { "json", "jsonc" },
  root_markers = { ".git" },
  settings = {
    json = {
      validate = { enable = true },
    },
  },
}
