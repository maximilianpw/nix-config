-- Real-plugin contracts, run inside the terminal package by tests/run.sh with
-- disposable HOME/XDG directories.
local root = assert(vim.env.NVIM_CONFIG_TEST_ROOT)
local tests = assert(vim.env.NVIM_TESTS)
local registry = require("config.plugins")

registry.trigger("nvim-treesitter")
vim.fn.mkdir(vim.fn.stdpath("state"), "p")
local fixture = vim.fs.joinpath(vim.fn.stdpath("state"), "textobjects.js")
vim.fn.writefile({ "function first() { return 1; }", "", "function second() { return 2; }" }, fixture)
vim.cmd.edit(vim.fn.fnameescape(fixture))
for _, key in ipairs({ "af", "if", "ac", "ic", "aa", "ia" }) do
  for _, mode in ipairs({ "x", "o" }) do
    assert(type(vim.fn.maparg(key, mode, false, true).callback) == "function", "Missing textobject: " .. key)
  end
end
for _, key in ipairs({ "]f", "]c", "]a", "]F", "]C", "]A", "[f", "[c", "[a", "[F", "[C", "[A" }) do
  assert(type(vim.fn.maparg(key, "n", false, true).callback) == "function", "Missing motion: " .. key)
end
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.fn.maparg("]f", "n", false, true).callback()
assert(vim.api.nvim_win_get_cursor(0)[1] == 3, "]f did not move to the second function")
vim.fn.maparg("[f", "n", false, true).callback()
assert(vim.api.nvim_win_get_cursor(0)[1] == 1, "[f did not move to the first function")
vim.b.bigfile = true
vim.b.bigfile_level = "max_ts"
vim.fn.maparg("]f", "n", false, true).callback()
assert(vim.api.nvim_win_get_cursor(0)[1] == 1, "Textobject motion ignored the bigfile guard")
vim.b.bigfile = false

local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "// " .. string.rep("x", vim.g.bigfile.huge) })
vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
assert(not vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "growing buffer retained highlighting")
assert(vim.bo.syntax == "off", "stopping Treesitter re-enabled legacy syntax in a large buffer")
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.api.nvim_exec_autocmds("TextChanged", { buffer = 0 })
assert(
  vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()],
  "shrinking buffer did not restart highlighting"
)
assert(vim.bo.indentexpr ~= "", "shrinking buffer did not restore treesitter indentation")

local blink = dofile(root .. "/lua/plugins/editor/blink.lua").opts
assert(blink.completion.list.selection.preselect == false, "Enter would accept an item the user did not select")
assert(vim.deep_equal(blink.keymap["<CR>"], { "accept", "fallback" }), "Enter is not explicit-selection accept")

registry.trigger("bufferline.nvim")
dofile(tests .. "/bufferline.lua")
print("plugin contracts passed")
