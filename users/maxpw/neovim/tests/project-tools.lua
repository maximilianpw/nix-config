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

local function same_path(left, right)
  return vim.uv.fs_realpath(left) == vim.uv.fs_realpath(right)
end

local repo = vim.fs.joinpath(temp, "repo")
local package_root = vim.fs.joinpath(repo, "packages", "app")
local source = vim.fs.joinpath(package_root, "src", "app.test.ts")
vim.fn.mkdir(vim.fs.joinpath(repo, ".git"), "p")
vim.fn.mkdir(vim.fs.dirname(source), "p")
vim.fn.writefile({ "{}" }, vim.fs.joinpath(package_root, "package.json"))
vim.fn.writefile({ "" }, source)
vim.cmd.edit(vim.fn.fnameescape(source))

local ran
package.loaded.neotest = { run = {
  run = function(path)
    ran = path
  end,
} }
local neotest_spec = dofile(vim.fs.joinpath(root, "lua", "plugins", "testing", "neotest.lua"))
for _, key in ipairs(neotest_spec.keys) do
  if key[1] == "<leader>tF" then
    key[2]()
  end
end
expect(same_path(ran, package_root), "run project did not select the nearest project root")

local adapter_options = {}
for _, name in ipairs({ "neotest-jest", "neotest-vitest", "neotest-mocha", "neotest-golang" }) do
  package.loaded[name] = function(opts)
    adapter_options[name] = opts
    return {}
  end
end
package.loaded.neotest.setup = function() end
neotest_spec.after()
vim.cmd.enew()
for _, name in ipairs({ "neotest-jest", "neotest-mocha" }) do
  expect(adapter_options[name].cwd(source) == package_root, name .. " ignored the test path when selecting cwd")
end

local inputs = {}
local original_input = vim.fn.input
vim.fn.input = function(prompt, default)
  table.insert(inputs, { prompt = prompt, default = default })
  return prompt == "Arguments: " and 'one "two words"' or "/tmp/program"
end

local dap_utils = {
  pick_process = function() end,
  splitstr = function(value)
    if value == "" then
      return {}
    end
    expect(value == 'one "two words"', "unexpected argument input")
    return { "one", "two words" }
  end,
}
package.loaded["dap.utils"] = dap_utils
package.loaded["dap-go"] = nil
package.preload["dap-go"] = function()
  error("not installed for isolated test")
end

local dap = { adapters = {}, configurations = {} }
require("config.dap.languages").setup(dap)
local rust = dap.configurations.rust
expect(rust[1].program() == "/tmp/program", "Rust executable prompt result was not used")
expect(inputs[1].default == vim.fn.getcwd() .. "/", "Rust executable prompt guessed a target path")
expect(vim.deep_equal(rust[2].args(), { "one", "two words" }), "quoted Rust arguments were not preserved")

vim.fn.input = function()
  return ""
end
expect(vim.deep_equal(rust[2].args(), {}), "blank Rust arguments did not produce an empty list")
vim.fn.input = original_input

cleanup()
print("project tool checks passed")
