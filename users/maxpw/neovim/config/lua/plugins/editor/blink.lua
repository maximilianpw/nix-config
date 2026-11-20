local spec = {
  "blink.cmp",
  event = "InsertEnter",
  before = function()
    require("config.plugins").packadd("friendly-snippets")
  end,
  opts = {
    -- On top of the "default" preset.
    keymap = {
      ["<C-e>"] = { "hide" },
      -- With preselect off, accept only acts on an item chosen with <C-n>/<C-p>/arrows.
      ["<CR>"] = { "accept", "fallback" },
      ["<C-p>"] = { "select_prev", "fallback" },
      ["<C-n>"] = { "select_next", "fallback" },
    },
    completion = {
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = "rounded" },
      },
      menu = {
        border = "rounded",
        draw = {
          treesitter = { "lsp" },
        },
      },
      list = {
        selection = { preselect = false, auto_insert = false },
      },
    },
    sources = {
      default = function()
        local sources = { "lsp", "path", "snippets" }
        -- lz.n loads LazyDev on FileType lua, not automatically on require.
        -- Blink constructs each listed provider even for signature help.
        if vim.bo.filetype == "lua" then
          table.insert(sources, 1, "lazydev")
        end
        if not (_G.is_bigfile and _G.is_bigfile(0, "max_ts")) then
          table.insert(sources, "buffer")
        end
        return sources
      end,
      providers = {
        lazydev = {
          name = "LazyDev",
          module = "lazydev.integrations.blink",
          score_offset = 100,
        },
      },
    },
    -- Nix builds the Rust matcher; never download a prebuilt binary, and fail
    -- visibly instead of silently falling back to the Lua implementation.
    fuzzy = {
      implementation = "rust",
      prebuilt_binaries = { download = false },
    },
    signature = {
      enabled = true,
      window = { border = "rounded" },
    },
  },
}

spec.after = function()
  require("blink.cmp").setup(spec.opts)
end

return spec
