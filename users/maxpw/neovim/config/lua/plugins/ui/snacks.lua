-- Nix injects the packaged helper; fall back to the chezmoi-era location.
local lazygit_nvim_edit_bin = vim.g.maxpw_lazygit_nvim_edit or vim.fn.expand("~/.local/bin/lazygit-nvim-edit")
local lazygit_nvim_edit = lazygit_nvim_edit_bin .. " -- {{filename}}"
local lazygit_nvim_edit_at_line = lazygit_nvim_edit_bin .. " --line {{line}} -- {{filename}}"
local lazygit_nvim_open_dir = lazygit_nvim_edit_bin .. " -- {{dir}}"

local spec = {
  "snacks.nvim",
  priority = 1000,
  lazy = false, -- Register dashboard hooks before the first UI event.
  opts = {
    -- ═══════════════════════════════════════════════════════════════
    -- 🎨 VISUAL & UI ENHANCEMENTS
    -- ═══════════════════════════════════════════════════════════════

    -- Visual indentation guides with scope highlighting
    indent = { enabled = true },
    -- Enhanced input dialogs with better UX
    input = { enabled = true },
    -- Beautiful notification system with animations
    notifier = { enabled = true },
    -- Scope-aware operations and highlighting
    scope = { enabled = true },
    -- Smooth scrolling animations
    scroll = { enabled = false },
    -- Advanced status column (disabled - set in options.lua)
    statuscolumn = { enabled = false },
    -- Quick scratch buffers for temporary notes
    scratch = { enabled = true },

    picker = { enabled = true },

    -- ═══════════════════════════════════════════════════════════════
    -- 💻 TERMINAL & DEVELOPMENT TOOLS
    -- ═══════════════════════════════════════════════════════════════

    -- Repository browsing and remote Git operations
    gitbrowse = { enabled = true },

    -- Git blame and history integration
    git = { enabled = true },

    -- lazygit
    lazygit = {
      enabled = true,
      config = {
        os = {
          editPreset = "",
          edit = lazygit_nvim_edit,
          editAtLine = lazygit_nvim_edit_at_line,
          editAtLineAndWait = lazygit_nvim_edit_at_line,
          openDirInEditor = lazygit_nvim_open_dir,
        },
      },
    },

    -- ═══════════════════════════════════════════════════════════════
    -- ⚡ PRODUCTIVITY & WORKFLOW
    -- ═══════════════════════════════════════════════════════════════

    -- Feature toggles and quick settings
    toggle = { enabled = true },

    -- Debug tools and inspection utilities
    debug = { enabled = true },

    -- Buffer deletion without disrupting layout
    bufdelete = { enabled = true },

    -- Smart file/symbol renaming with LSP integration
    rename = { enabled = true },

    -- Large file handling (disabled - using consolidated config/bigfile.lua)
    bigfile = { enabled = false },

    -- Our treesitter setup owns early highlighting and checks the shared size
    -- tiers; quickfile only recognizes Snacks' separate `bigfile` filetype.
    quickfile = { enabled = false },

    -- Word movement and selection enhancements with LSP references
    words = { enabled = true },

    -- File explorer integration (disabled in favor of neo-tree)
    explorer = { enabled = false },

    -- ═══════════════════════════════════════════════════════════════
    -- 🏠 DASHBOARD CONFIGURATION
    -- ═══════════════════════════════════════════════════════════════
    dashboard = {
      enabled = true,
      width = 80,
      -- Sections belong on dashboard, not preset. Override Snacks' default
      -- startup section, which requires lazy.stats (we use Nixvim + lz.n).
      sections = {
        {
          section = "header",
          width = 40,
          padding = 1,
        },
        {
          section = "keys",
          height = 5,
          padding = 1,
        },
        { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
        { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
      },
      preset = {
        -- Dashboard quick action keys (using Snacks picker)
        keys = {
          {
            icon = " ",
            key = "f",
            desc = "Find File",
            action = function()
              require("fff").find_files()
            end,
          },
          { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
          {
            icon = " ",
            key = "g",
            desc = "Find Text",
            action = function()
              require("fff").live_grep()
            end,
          },
          {
            icon = " ",
            key = "r",
            desc = "Recent Files",
            action = function()
              require("snacks").picker.recent()
            end,
          },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
    },
  },
  -- ═══════════════════════════════════════════════════════════════
  -- ⌨️  COMPREHENSIVE KEYMAPS FOR ALL SNACKS FEATURES
  -- ═══════════════════════════════════════════════════════════════
  keys = {
    -- ────────────────────────────────────────────────────────────
    -- 📋 NOTIFICATIONS & DEBUG
    -- ────────────────────────────────────────────────────────────
    {
      "<leader>nn",
      function()
        require("snacks").notifier.show_history()
      end,
      desc = "Notification History",
    },
    {
      "<leader>nd",
      function()
        require("snacks").notifier.hide()
      end,
      desc = "Dismiss All Notifications",
    },

    -- ────────────────────────────────────────────────────────────
    -- 🌿 GIT INTEGRATION
    -- ────────────────────────────────────────────────────────────
    {
      "<leader>gg",
      function()
        require("snacks").lazygit.open()
      end,
      desc = "Lazygit",
    },
    {
      "<leader>D",
      function()
        vim.cmd("terminal lazydocker")
      end,
      desc = "Lazydocker",
    },
    {
      "<leader>gf",
      function()
        require("snacks").lazygit.log_file()
      end,
      desc = "Lazygit Current File History",
    },
    {
      "<leader>gl",
      function()
        require("snacks").lazygit.log()
      end,
      desc = "Lazygit Log (cwd)",
    },
    {
      "<leader>gb",
      function()
        require("snacks").git.blame_line()
      end,
      desc = "Git Blame Line",
    },
    {
      "<leader>gB",
      function()
        require("snacks").gitbrowse()
      end,
      desc = "Git Browse (Open in Browser)",
    },

    -- ────────────────────────────────────────────────────────────
    -- ⚡ PRODUCTIVITY & WORKFLOW
    -- ────────────────────────────────────────────────────────────
    {
      "<leader>bd",
      function()
        require("snacks").bufdelete()
      end,
      desc = "Delete Buffer (preserve layout)",
    },
    {
      "<leader>.",
      function()
        require("snacks").scratch()
      end,
      desc = "Toggle Scratch Buffer",
    },
    {
      "<leader>S",
      function()
        require("snacks").scratch.select()
      end,
      desc = "Select Scratch Buffer",
    },
    {
      "<leader>fd",
      function()
        require("snacks").picker.diagnostics()
      end,
      desc = "Find Diagnostics",
    },
    {
      "<leader>f.",
      function()
        require("snacks").picker.recent()
      end,
      desc = "Find Recent Files",
    },
    {
      "<leader>fs",
      function()
        require("snacks").picker.lsp_symbols()
      end,
      desc = "Find Symbols",
    },
  },
  beforeAll = function()
    -- ═══════════════════════════════════════════════════════════════
    -- 🚀 INITIALIZATION & AUTO-SETUP
    -- ═══════════════════════════════════════════════════════════════

    vim.api.nvim_create_autocmd("User", {
      pattern = "DeferredUIEnter",
      callback = function()
        -- ────────────────────────────────────────────────────────────
        -- 🎨 UI CUSTOMIZATION
        -- ────────────────────────────────────────────────────────────
        local dashboard_blue = "#89B4FA"
        vim.api.nvim_set_hl(0, "SnacksDashboardHeader", {
          fg = dashboard_blue,
          bold = true,
        })
      end,
    })
  end,
}

spec.after = function()
  require("snacks").setup(spec.opts)
end

return spec
