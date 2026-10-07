return {
  "nvim-dap",
  before = function()
    require("config.plugins").packadd(
      "nvim-dap-ui",
      "nvim-dap-virtual-text",
      "persistent-breakpoints.nvim",
      "nvim-dap-go"
    )
  end,
  keys = {
    {
      "<leader>dc",
      function()
        require("dap").continue()
      end,
      desc = "Debug: Start/Continue",
    },
    {
      "<leader>di",
      function()
        require("dap").step_into()
      end,
      desc = "Debug: Step Into",
    },
    {
      "<leader>do",
      function()
        require("dap").step_over()
      end,
      desc = "Debug: Step Over",
    },
    {
      "<leader>dO",
      function()
        require("dap").step_out()
      end,
      desc = "Debug: Step Out",
    },
    {
      "<leader>db",
      function()
        require("persistent-breakpoints.api").toggle_breakpoint()
      end,
      desc = "Debug: Toggle Breakpoint",
    },
    {
      "<leader>dB",
      function()
        require("persistent-breakpoints.api").set_conditional_breakpoint()
      end,
      desc = "Debug: Set Conditional Breakpoint",
    },
    {
      "<leader>dr",
      function()
        require("dap").repl.open()
      end,
      desc = "Debug: Open REPL",
    },
    {
      "<leader>dl",
      function()
        require("dap").run_last()
      end,
      desc = "Debug: Run Last",
    },
    {
      "<leader>dt",
      function()
        require("dap").terminate()
      end,
      desc = "Debug: Terminate",
    },
    {
      "<leader>du",
      function()
        require("dapui").toggle()
      end,
      desc = "Debug: Toggle UI",
    },
    {
      "<leader>de",
      function()
        require("dapui").eval()
      end,
      desc = "Debug: Evaluate Expression",
      mode = { "n", "v" },
    },
    {
      "<leader>dR",
      function()
        require("dap").restart()
      end,
      desc = "Debug: Restart",
    },
    {
      "<leader>dC",
      function()
        require("dap").run_to_cursor()
      end,
      desc = "Debug: Run to Cursor",
    },
    {
      "<leader>dh",
      function()
        require("dap.ui.widgets").hover()
      end,
      desc = "Debug: Hover Variables",
      mode = { "n", "v" },
    },
    {
      "<leader>dj",
      function()
        require("dap").down()
      end,
      desc = "Debug: Down Stack Frame",
    },
    {
      "<leader>dk",
      function()
        require("dap").up()
      end,
      desc = "Debug: Up Stack Frame",
    },
  },
  after = function()
    local dap = require("dap")
    local dapui = require("dapui")

    require("config.dap.ui").setup(dap, dapui)
    require("config.dap.js").setup(dap)
    require("config.dap.languages").setup(dap)
    require("config.dap.breakpoints").setup()
  end,
}
