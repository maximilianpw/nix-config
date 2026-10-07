local root = assert(vim.env.NVIM_CONFIG_TEST_ROOT, "NVIM_CONFIG_TEST_ROOT is required")
vim.opt.runtimepath:prepend(root)

local temp = vim.fn.tempname()
vim.fn.mkdir(temp, "p")

local function cleanup()
  vim.fn.delete(temp, "rf")
end

local function expect(condition, message)
  if not condition then
    cleanup()
    error(message)
  end
end

local function write(path, contents)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ contents or "{}" }, path, "b")
end

local function fixture(name, configs, relative, ft)
  local repo = vim.fs.joinpath(temp, name)
  vim.fn.mkdir(vim.fs.joinpath(repo, ".git"), "p")
  for config, contents in pairs(configs) do
    write(vim.fs.joinpath(repo, config), contents)
  end
  local path = vim.fs.joinpath(repo, relative)
  write(path, "fixture")
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(bufnr, path)
  vim.bo[bufnr].filetype = ft
  return bufnr
end

local spec = dofile(vim.fs.joinpath(root, "lua", "plugins", "style", "autoformat.lua"))
local opts = spec.opts()
local function names(bufnr, ft)
  return table.concat(opts.formatters_by_ft[ft](bufnr), ",")
end

for _, case in ipairs({
  { "ts", "typescript" },
  { "md", "markdown" },
  { "yaml", "yaml" },
  { "html", "html" },
}) do
  local bufnr = fixture("prettier-" .. case[1], { [".prettierrc"] = "{}" }, "src/file." .. case[1], case[2])
  expect(names(bufnr, case[2]) == "prettierd,prettier", case[2] .. " did not select Prettier")
end

local biome = fixture("biome-only", { ["biome.json"] = "{}" }, "src/file.ts", "typescript")
expect(names(biome, "typescript") == "biome", "Biome-only TypeScript selection")
local unsupported = fixture("biome-markdown", { ["biome.json"] = "{}" }, "README.md", "markdown")
expect(names(unsupported, "markdown") == "", "unsupported Biome filetype was selected")
expect(
  table.concat(opts.formatters_by_ft.markdown(unsupported), ",") == "",
  "formatters_by_ft disagreed with ownership"
)

local mixed = fixture("mixed", { ["biome.json"] = "{}", [".prettierrc"] = "{}" }, "src/file.ts", "typescript")
expect(names(mixed, "typescript") == "biome", "Biome did not own a mixed supported project")
local mixed_md = fixture("mixed-md", { ["biome.json"] = "{}", [".prettierrc"] = "{}" }, "README.md", "markdown")
expect(names(mixed_md, "markdown") == "prettierd,prettier", "Prettier did not own mixed Markdown")

for _, case in ipairs({
  { name = "eslint-only", configs = { ["eslint.config.js"] = "export default []" } },
  { name = "no-config", configs = {} },
}) do
  local bufnr = fixture(case.name, case.configs, "src/file.ts", "typescript")
  expect(names(bufnr, "typescript") == "", "unconfigured fallback formatter was selected")
  expect(opts.format_on_save(bufnr).lsp_format == "never", "ESLint/no-config allowed LSP formatting")
end

local outer = vim.fs.joinpath(temp, "boundary")
vim.fn.mkdir(vim.fs.joinpath(outer, ".git"), "p")
write(vim.fs.joinpath(outer, ".prettierrc"), "{}")
local inner = vim.fs.joinpath(outer, "inner")
vim.fn.mkdir(vim.fs.joinpath(inner, ".git"), "p")
local bounded = fixture("placeholder", {}, "file.ts", "typescript")
vim.api.nvim_buf_set_name(bounded, vim.fs.joinpath(inner, "file.ts"))
expect(names(bounded, "typescript") == "", "formatter lookup crossed a VCS boundary")

for _, name in ipairs({
  "prettier.config.ts",
  "prettier.config.mts",
  "prettier.config.cts",
  ".prettierrc.ts",
  ".prettierrc.mts",
  ".prettierrc.cts",
}) do
  local bufnr = fixture("modern-" .. name, { [name] = "export default {}" }, "src/file.ts", "typescript")
  expect(names(bufnr, "typescript") == "prettierd,prettier", name .. " was not recognized")
end
local tooling = require("util.tooling")
for _, name in ipairs({ "eslint.config.ts", "eslint.config.mts", "eslint.config.cts" }) do
  expect(vim.tbl_contains(tooling.eslint, name), name .. " was not registered")
end

local c = fixture("c", {}, "main.c", "c")
expect(opts.format_on_save(c).lsp_format == "never", "C enabled LSP fallback")

local manual
package.loaded.conform = {
  format = function(options)
    manual = options
  end,
}
vim.api.nvim_set_current_buf(unsupported)
for _, key in ipairs(spec.keys) do
  key[2]()
  expect(manual.async and manual.lsp_format == "never", key[1] .. " bypassed formatter ownership")
end

local old_is_bigfile = _G.is_bigfile
_G.is_bigfile = function()
  return true
end
expect(opts.format_on_save(c) == nil, "huge file autoformat guard was lost")
_G.is_bigfile = old_is_bigfile

cleanup()
print("formatting checks passed")
