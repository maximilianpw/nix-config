-- Headless startup does not open the dashboard; exercise its actual renderer.
assert(not pcall(require, "lazy.stats"), "Regression requires lazy.nvim to be absent")
local dashboard = require("snacks").dashboard.open()
assert(dashboard, "Dashboard did not open")
assert(vim.bo.filetype == "snacks_dashboard", "Dashboard buffer was not displayed")
local lines = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(lines:find("Find File", 1, true), "Dashboard actions were not rendered")
assert(lines:find("Recent Files", 1, true), "Custom dashboard sections were not rendered")
