local spec = {
  "lualine.nvim",
  event = "DeferredUIEnter",
  beforeAll = function()
    vim.g.lualine_laststatus = vim.o.laststatus
    if vim.fn.argc(-1) > 0 then
      vim.o.statusline = " "
    else
      vim.o.laststatus = 0
    end
  end,
  opts = function()
    local icons = {
      diagnostics = { Error = "󰅚 ", Warn = "󰀪 ", Info = "󰋽 ", Hint = "󰌶 " },
      git = { added = "+", modified = "~", removed = "-" },
    }

    -- Cache git root for performance (avoid repeated git calls)
    local cached_root = nil
    local cached_cwd = nil

    local function get_root()
      local cwd = vim.fn.getcwd()
      if cached_cwd == cwd and cached_root then
        return cached_root
      end

      -- Use vim.fs.find for faster .git detection
      local git_dir = vim.fs.find(".git", {
        upward = true,
        path = cwd,
        type = "directory",
      })[1]

      if git_dir then
        local git_root = vim.fn.fnamemodify(git_dir, ":h")
        cached_root = vim.fn.fnamemodify(git_root, ":~")
      else
        cached_root = vim.fn.fnamemodify(cwd, ":~")
      end
      cached_cwd = cwd
      return cached_root
    end

    -- Clear cache on directory change
    vim.api.nvim_create_autocmd("DirChanged", {
      callback = function()
        cached_root = nil
        cached_cwd = nil
      end,
    })

    -- Cache highlight-derived colors (invalidated on colorscheme change)
    local cached_colors = {}
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = function()
        cached_colors = {}
      end,
    })
    local function get_hl_color(hl, fallback)
      if not cached_colors[hl] then
        cached_colors[hl] = package.loaded["snacks"] and require("snacks").util.color(hl) or fallback
      end
      return cached_colors[hl]
    end

    vim.o.laststatus = vim.g.lualine_laststatus

    local opts = {
      options = {
        theme = "auto",
        globalstatus = vim.o.laststatus == 3,
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = { statusline = { "dashboard", "alpha", "ministarter", "snacks_dashboard" } },
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch" },
        lualine_c = {
          { get_root, icon = "󰉋 ", color = { gui = "bold" } },
          {
            "diagnostics",
            symbols = icons.diagnostics,
            color = { error = "#ec5f67", warn = "#fac863", info = "#5fb3b3", hint = "#737aa2" },
          },
          { "filetype", icon_only = true, separator = "", padding = { left = 1, right = 0 } },
          {
            "filename",
            path = 1,
            shorting_target = 40,
            symbols = { modified = " ●", readonly = " ", unnamed = "[No Name]" },
          },
        },
        lualine_x = {
          {
            function()
              if package.loaded["snacks"] then
                return require("snacks").profiler.status()
              end
            end,
            cond = function()
              return package.loaded["snacks"] and require("snacks").profiler.status() ~= ""
            end,
          },
          {
            function()
              return require("noice").api.status.command.get()
            end,
            cond = function()
              return package.loaded["noice"] and require("noice").api.status.command.has()
            end,
            color = function()
              return { fg = get_hl_color("Statement", "#7aa2f7") }
            end,
          },
          {
            function()
              return require("noice").api.status.mode.get()
            end,
            cond = function()
              return package.loaded["noice"] and require("noice").api.status.mode.has()
            end,
            color = function()
              return { fg = get_hl_color("Constant", "#bb9af7") }
            end,
          },
          {
            function()
              local s = package.loaded["dap"] and require("dap").status() or ""
              return s ~= "" and "  " .. s or ""
            end,
            cond = function()
              return package.loaded["dap"] and require("dap").status() ~= ""
            end,
            color = function()
              return { fg = get_hl_color("Debug", "#ff9e64") }
            end,
          },
          {
            "diff",
            symbols = icons.git,
            source = function()
              local g = vim.b.gitsigns_status_dict
              return g and { added = g.added, modified = g.changed, removed = g.removed }
            end,
          },
        },
        lualine_y = {
          { "encoding", icon = "" },
          { "fileformat", symbols = { unix = "LF", dos = "CRLF", mac = "CR" } },
          { "progress", separator = " ", padding = { left = 1, right = 0 } },
          { "location", padding = { left = 0, right = 1 } },
        },
        lualine_z = {
          {
            function()
              local clients = vim.lsp.get_clients({ bufnr = 0 })
              return clients[1] and clients[1].name or ""
            end,
          },
          {
            function()
              return " " .. os.date("%R")
            end,
          },
        },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { "filename" },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },
    }

    return opts
  end,
}

spec.after = function()
  require("lualine").setup(spec.opts())
end

return spec
