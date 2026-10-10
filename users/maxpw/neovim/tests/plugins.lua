-- Real-plugin contracts, run inside the terminal package by tests/run.sh with
-- disposable HOME/XDG directories.
local root = assert(vim.env.NVIM_CONFIG_TEST_ROOT)
local tests = assert(vim.env.NVIM_TESTS)
local registry = require("config.plugins")

local function plugin_dir(name)
  local dirs = vim.fn.globpath(vim.o.packpath, "pack/*/*/" .. name, false, true)
  assert(#dirs == 1, "expected exactly one packaged copy of " .. name .. ", found " .. #dirs)
  return dirs[1]
end

-- Press keys through Neovim's input path. "x" drains typeahead, including the
-- keys lz.n's stub mapping re-feeds after loading the plugin, so this exercises
-- the installed mapping on its first press exactly as a user would.
local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "mx", false)
end

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

-- Inspect merged key configuration without starting the AI service.
local ai = dofile(plugin_dir("supermaven-nvim") .. "/lua/supermaven-nvim/config.lua")
ai.setup(dofile(root .. "/lua/plugins/ai/supermaven.lua").opts)
local blink = dofile(root .. "/lua/plugins/editor/blink.lua").opts
local tab = blink.keymap["<Tab>"]
assert(blink.keymap.preset == "default", "Blink default completion preset is disabled")
assert(type(tab) == "table", "Blink contextual Tab mapping is missing")
assert(#tab == 3 and tab[1] == "snippet_forward" and tab[3] == "fallback", "Blink Tab priority is misconfigured")
assert(blink.completion.list.selection.preselect == false, "Enter would accept an item the user did not select")
assert(vim.deep_equal(blink.keymap["<CR>"], { "accept", "fallback" }), "Enter is not explicit-selection accept")

local preview_module = "supermaven-nvim.completion_preview"
local original_preview = package.loaded[preview_module]
local supermaven_accepted = false
package.loaded[preview_module] = {
  has_suggestion = function()
    return true
  end,
  on_accept_suggestion = function()
    supermaven_accepted = true
  end,
}
-- Capture the undo-break keys instead of letting a later drain run them in Normal mode.
local feedkeys, fed = vim.api.nvim_feedkeys, nil
vim.api.nvim_feedkeys = function(keys)
  fed = keys
end
local handled = tab[2]()
vim.api.nvim_feedkeys = feedkeys
assert(handled == true, "Blink Tab did not handle visible Supermaven text")
assert(fed == vim.keycode("<C-g>u"), "Supermaven acceptance does not start a new undo step")
assert(not supermaven_accepted, "Blink Tab accepted Supermaven text while Neovim may hold a text lock")
vim.wait(100, function()
  return supermaven_accepted
end)
assert(supermaven_accepted, "Blink Tab did not accept visible Supermaven text after deferring")
package.loaded[preview_module] = {
  has_suggestion = function()
    return false
  end,
}
assert(tab[2]() == nil, "Blink Tab blocked indentation without a Supermaven suggestion")
package.loaded[preview_module] = original_preview

assert(blink.keymap[ai.keymaps.accept_suggestion] == nil, "AI acceptance conflicts with Blink")
assert(ai.keymaps.accept_suggestion ~= "<Tab>", "AI direct acceptance still owns contextual Tab")

-- Use the real persistence APIs through the configured keys, then emulate
-- late setup with an already-open buffer and no in-memory DAP breakpoints.
press(" db")
local bps = require("dap.breakpoints")
local buf = vim.api.nvim_get_current_buf()
assert(bps.get()[buf][1].line == 1, "Toggle mapping did not create a breakpoint")
bps.clear()
require("config.dap.breakpoints").setup()
assert(bps.get()[buf] and bps.get()[buf][1].line == 1, "Breakpoint was not persisted/restored on late setup")
local input = vim.fn.input
vim.fn.input = function()
  return "value > 1"
end
vim.api.nvim_win_set_cursor(0, { 3, 0 })
press(" dB")
vim.fn.input = input
bps.clear()
require("config.dap.breakpoints").setup()
assert(bps.get()[buf][2].condition == "value > 1", "Conditional breakpoint was not persisted")

for _, case in ipairs({
  { "", {} },
  { "   ", {} },
  { [[one "two words" 'three words']], { "one", "two words", "three words" } },
}) do
  vim.fn.input = function()
    return case[1]
  end
  assert(vim.deep_equal(require("dap").configurations.rust[2].args(), case[2]), "Rust argument parsing failed")
end
vim.fn.input = input

registry.trigger("bufferline.nvim")
dofile(tests .. "/bufferline.lua")
print("plugin contracts passed")
