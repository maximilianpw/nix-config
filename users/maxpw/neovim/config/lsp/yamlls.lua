-- Schemas are injected dynamically via vim.lsp.config in lsp/init.lua
return {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab" },
  root_markers = { ".git" },
  settings = {
    yaml = {
      schemaStore = {
        enable = false, -- Use schemastore.nvim instead
        url = "",
      },
    },
  },
}
