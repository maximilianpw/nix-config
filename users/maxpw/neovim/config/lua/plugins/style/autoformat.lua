local prettier_ft = {
  "javascript",
  "javascriptreact",
  "typescript",
  "typescriptreact",
  "vue",
  "css",
  "scss",
  "less",
  "html",
  "json",
  "jsonc",
  "yaml",
  "markdown",
  "graphql",
}

local prettier_ft_set = {}
for _, ft in ipairs(prettier_ft) do
  prettier_ft_set[ft] = true
end

-- Biome's formatter does not support every filetype handled by Prettier.
local biome_ft = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  vue = true,
  css = true,
  json = true,
  jsonc = true,
  graphql = true,
}

local function web_formatters(bufnr, ft)
  local fs = require("util.fs")
  local tooling = require("util.tooling")

  if biome_ft[ft] and fs.has_config(bufnr, tooling.biome) then
    return { "biome", stop_after_first = true }
  end
  if tooling.has_prettier_config(bufnr) then
    return { "prettierd", "prettier", stop_after_first = true }
  end
  return {}
end

local function format_options(bufnr)
  local ft = vim.bo[bufnr].filetype
  if prettier_ft_set[ft] then
    -- These filetypes are project-tool owned. In particular, an ESLint root is
    -- not a formatter: the ESLint LSP has formatting disabled.
    return { timeout_ms = 2000, lsp_format = "never" }
  end

  return {
    timeout_ms = 2000,
    lsp_format = (ft == "c" or ft == "cpp") and "never" or "fallback",
  }
end

local function format_buffer()
  local options = format_options(0)
  options.async = true
  require("conform").format(options)
end

local spec = {
  "conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    { "<leader>cf", format_buffer, mode = { "n", "v" }, desc = "Format buffer (Conform)" },
    {
      "<leader>cF",
      format_buffer,
      mode = { "n", "v" },
      desc = "Format buffer (Conform)",
    },
  },
  opts = function()
    local formatters_by_ft = {
      lua = { "stylua" },
      nix = { "alejandra" },
      go = { "goimports", "gofmt" },
      c = { "clang_format" },
      cpp = { "clang_format" },
      rust = { "rustfmt" },
      terraform = { "terraform_fmt" },
      python = { "ruff_format", "black", stop_after_first = true },
      sh = { "shfmt" },
      bash = { "shfmt" },
      zsh = { "shfmt" },
      toml = { "taplo" },
      zig = { "zigfmt" },
    }

    for _, ft in ipairs(prettier_ft) do
      formatters_by_ft[ft] = function(bufnr)
        return web_formatters(bufnr, ft)
      end
    end

    return {
      notify_on_error = true,

      format_on_save = function(bufnr)
        if _G.is_bigfile and _G.is_bigfile(bufnr, "huge") then
          return nil
        end

        return format_options(bufnr)
      end,

      formatters_by_ft = formatters_by_ft,
    }
  end,
}

spec.after = function()
  require("conform").setup(spec.opts())
end

return spec
