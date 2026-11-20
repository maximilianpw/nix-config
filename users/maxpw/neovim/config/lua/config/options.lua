-- Declarative options live in users/maxpw/neovim/options.nix. Only behavior
-- that is not a plain option assignment stays here.

-- Sync clipboard between OS and Neovim after startup; resolving the provider
-- eagerly measurably slows startup.
vim.schedule(function()
  if vim.fn.has("linux") == 1 and not (vim.env.WAYLAND_DISPLAY or vim.env.DISPLAY or vim.env.TMUX) then
    -- Remote (Rex, SSH): yanks go to the client's clipboard over OSC 52. Reading
    -- it back would query the terminal on every `p`, so pastes return the last
    -- yank; the terminal's own paste brings in client text.
    local osc52 = require("vim.ui.clipboard.osc52")
    local last = {}
    local function copy(reg)
      local send = osc52.copy(reg)
      return function(lines, regtype)
        last[reg] = { lines, regtype }
        send(lines)
      end
    end
    local function paste(reg)
      return function()
        return last[reg] or {}
      end
    end
    vim.g.clipboard = {
      name = "OSC 52 (copy only)",
      copy = { ["+"] = copy("+"), ["*"] = copy("*") },
      paste = { ["+"] = paste("+"), ["*"] = paste("*") },
    }
  end
  vim.opt.clipboard = "unnamedplus"
end)
