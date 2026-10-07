local function project_root(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if path == "" then
    path = vim.fn.getcwd()
  end

  return vim.fs.root(path, { "package.json", "go.mod", "Cargo.toml", ".git", ".jj" }) or vim.fn.getcwd()
end

return {
  "neotest",
  before = function()
    local plugins = require("config.plugins")
    plugins.trigger("nvim-treesitter")
    plugins.packadd("neotest-jest", "neotest-vitest", "neotest-mocha", "neotest-golang")
  end,
  keys = {
    {
      "<leader>tn",
      function()
        require("neotest").run.run()
      end,
      desc = "Test: Run nearest",
    },
    {
      "<leader>tf",
      function()
        require("neotest").run.run(vim.fn.expand("%"))
      end,
      desc = "Test: Run file",
    },
    {
      "<leader>tF",
      function()
        require("neotest").run.run(project_root())
      end,
      desc = "Test: Run project",
    },
    {
      "<leader>ts",
      function()
        require("neotest").summary.toggle()
      end,
      desc = "Test: Toggle summary",
    },
    {
      "<leader>to",
      function()
        require("neotest").output.open({ enter = true })
      end,
      desc = "Test: Open output",
    },
    {
      "<leader>tO",
      function()
        require("neotest").output_panel.toggle()
      end,
      desc = "Test: Toggle output panel",
    },
    {
      "<leader>td",
      function()
        require("neotest").run.run({ strategy = "dap" })
      end,
      desc = "Test: Debug nearest (DAP)",
    },
    {
      "<leader>tS",
      function()
        require("neotest").run.run({ suite = true })
      end,
      desc = "Test: Run suite (nearest root)",
    },
  },
  after = function()
    require("neotest").setup({
      adapters = {
        require("neotest-jest")({ cwd = project_root }),
        require("neotest-vitest")({
          filter_dir = function(name, rel_path, root)
            return name ~= "node_modules" and name ~= "dist"
          end,
        }),
        require("neotest-mocha")({
          env = { CI = true },
          cwd = project_root,
        }),
        require("neotest-golang")({
          go_test_args = { "-v", "-count=1" },
        }),
      },
    })
  end,
}
