-- Canonical config-file name lists for JS/TS tooling.
-- Shared by conform (formatting), nvim-lint (linting), and lsp/ server specs so
-- the "what files mark a prettier/biome/eslint/oxlint project" answer lives in one place.

local M = {}

-- https://prettier.io/docs/configuration
M.prettier = {
  ".prettierrc",
  ".prettierrc.json",
  ".prettierrc.yml",
  ".prettierrc.yaml",
  ".prettierrc.json5",
  ".prettierrc.js",
  ".prettierrc.cjs",
  ".prettierrc.mjs",
  ".prettierrc.ts",
  ".prettierrc.cts",
  ".prettierrc.mts",
  ".prettierrc.toml",
  "prettier.config.js",
  "prettier.config.cjs",
  "prettier.config.mjs",
  "prettier.config.ts",
  "prettier.config.cts",
  "prettier.config.mts",
}

M.biome = {
  "biome.json",
  "biome.jsonc",
}

M.eslint = {
  ".eslintrc",
  ".eslintrc.js",
  ".eslintrc.cjs",
  ".eslintrc.mjs",
  ".eslintrc.json",
  ".eslintrc.yaml",
  ".eslintrc.yml",
  "eslint.config.js",
  "eslint.config.mjs",
  "eslint.config.cjs",
  "eslint.config.ts",
  "eslint.config.mts",
  "eslint.config.cts",
}

M.oxlint = {
  "oxlintrc.json",
  ".oxlintrc.json",
}

local function package_has_prettier(path)
  local ok_read, lines = pcall(vim.fn.readfile, path)
  if not ok_read then
    return false
  end

  local ok_decode, package = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(package) ~= "table" then
    return false
  end

  local prettier = package.prettier
  if type(prettier) == "string" then
    return prettier ~= ""
  end
  return type(prettier) == "table" and not vim.islist(prettier)
end

function M.has_prettier_config(bufnr)
  local fs = require("util.fs")
  return fs.has_config(bufnr, M.prettier) or fs.has_config(bufnr, { "package.json" }, package_has_prettier)
end

return M
