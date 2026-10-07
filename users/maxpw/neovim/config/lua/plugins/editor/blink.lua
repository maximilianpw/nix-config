local spec = {
  "blink.cmp",
  event = "InsertEnter",
  before = function()
    require("config.plugins").packadd("friendly-snippets")
  end,
  opts = {
    keymap = {
      preset = "default",
      ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-e>"] = { "hide" },
      ["<CR>"] = { "accept", "fallback" },
      -- Prefer Blink's menu, then snippet navigation, then Supermaven, then indentation.
      ["<Tab>"] = {
        function(cmp)
          if cmp.is_menu_visible() then
            return cmp.select_and_accept()
          end
        end,
        "snippet_forward",
        function()
          local ok, suggestion = pcall(require, "supermaven-nvim.completion_preview")
          if ok and suggestion.has_suggestion() then
            -- Blink invokes keymap handlers while Neovim may still hold a text lock.
            vim.schedule(suggestion.on_accept_suggestion)
            return true
          end
        end,
        "fallback",
      },
      ["<S-Tab>"] = { "snippet_backward", "fallback" },
      ["<Up>"] = { "select_prev", "fallback" },
      ["<Down>"] = { "select_next", "fallback" },
      ["<C-p>"] = { "select_prev", "fallback" },
      ["<C-n>"] = { "select_next", "fallback" },
      ["<C-b>"] = { "scroll_documentation_up", "fallback" },
      ["<C-f>"] = { "scroll_documentation_down", "fallback" },
    },
    appearance = {
      use_nvim_cmp_as_default = false,
      nerd_font_variant = "mono",
    },
    completion = {
      accept = {
        auto_brackets = { enabled = true },
      },
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = "rounded" },
      },
      menu = {
        border = "rounded",
        draw = {
          columns = { { "kind_icon" }, { "label", "label_description", gap = 1 } },
          treesitter = { "lsp" },
        },
      },
      list = {
        selection = { preselect = true, auto_insert = false },
      },
      ghost_text = { enabled = false },
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
    snippets = { preset = "default" },
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
