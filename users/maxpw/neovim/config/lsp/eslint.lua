return {
  cmd = { "vscode-eslint-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "vue" },
  root_markers = require("util.tooling").eslint,
  settings = {
    validate = "on",
    packageManager = nil,
    useESLintClass = false,
    experimental = { useFlatConfig = "auto" },
    codeActionOnSave = { enable = false, mode = "all" },
    format = false,
    quiet = false,
    onIgnoredFiles = "off",
    rulesCustomizations = {},
    run = "onType",
    problems = { shortenToSingleLine = false },
    codeAction = {
      disableRuleComment = { enable = true, location = "separateLine" },
      showDocumentation = { enable = true },
    },
    workingDirectory = { mode = "location" },
  },
}
