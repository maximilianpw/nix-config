-- lazydev.nvim adds the Neovim runtime and plugin libraries for Neovim config workspaces.
return {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      completion = { callSnippet = "Replace" },
      workspace = { checkThirdParty = false },
    },
  },
}
