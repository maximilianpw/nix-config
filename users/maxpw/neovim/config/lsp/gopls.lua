return {
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = { "go.work", "go.mod", ".git" },
  settings = {
    gopls = {
      staticcheck = true,
      gofumpt = true,
      analyses = {
        unusedparams = true,
        nilness = true,
        shadow = true,
        unusedwrite = true,
        useany = true,
      },
      hints = {
        assignVariableTypes = false,
        compositeLiteralFields = false,
        compositeLiteralTypes = false,
        constantValues = false,
        parameterNames = true,
        rangeVariableTypes = false,
      },
      codelenses = {
        gc_details = false,
        generate = true,
        regenerate_cgo = true,
        test = true,
        tidy = true,
        upgrade_dependency = true,
        vendor = true,
      },
    },
  },
}
