-- Shared byte thresholds. Reads use disk size before plugins load; edits use
-- Neovim's buffer offsets without copying/scanning the text on every keystroke.
vim.g.bigfile = {
  large = 100 * 1024,
  max_ts = 150 * 1024,
  huge = 200 * 1024,
}

local buffers, windows = {}, {}

_G.is_bigfile = function(bufnr, level)
  if not vim.b[bufnr or 0].bigfile then
    return false
  end
  local tier = vim.b[bufnr or 0].bigfile_level
  level = level or "large"
  return tier ~= nil and (level == "large" or tier == "huge" or (level == "max_ts" and tier == "max_ts"))
end

local function classify(bufnr, disk)
  local size = 0
  if vim.bo[bufnr].buftype == "" then
    if disk then
      local stat = vim.uv.fs_stat(vim.api.nvim_buf_get_name(bufnr))
      size = stat and stat.size or 0
    else
      size = vim.api.nvim_buf_get_offset(bufnr, vim.api.nvim_buf_line_count(bufnr))
      if not vim.bo[bufnr].endofline then
        size = size - 1
      end
    end
  end
  local tier
  for _, level in ipairs({ "huge", "max_ts", "large" }) do
    if size > vim.g.bigfile[level] then
      tier = level
      break
    end
  end
  vim.b[bufnr].bigfile = tier ~= nil
  vim.b[bufnr].bigfile_level = tier
end

-- Restore only values we still own, not an option the user changed afterwards.
local function option(options, saved, name, disabled)
  if disabled ~= nil then
    if not saved[name] or options[name] ~= saved[name].disabled then
      saved[name] = { original = options[name], disabled = disabled }
    end
    options[name] = disabled
  elseif saved[name] then
    if options[name] == saved[name].disabled then
      options[name] = saved[name].original
    end
    saved[name] = nil
  end
end

local function window_policy(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local state = windows[win] or { history = {} }
  windows[win] = state
  local history = state.history
  -- Window-local values can be remembered per buffer by Neovim. Keep their
  -- original values too, so returning to a still-large buffer doesn't lose them.
  if state.buf ~= buf then
    for name, saved in pairs(history[state.buf] or {}) do
      if vim.wo[win][name] == saved.disabled then
        vim.wo[win][name] = saved.original
      end
    end
  end
  state.buf = buf
  local saved = history[buf] or {}
  local large, max_ts = _G.is_bigfile(buf), _G.is_bigfile(buf, "max_ts")
  local off
  if large then
    off = false
  end
  option(vim.wo[win], saved, "cursorline", off)
  option(vim.wo[win], saved, "relativenumber", off)
  option(vim.wo[win], saved, "scrolloff", large and 3 or nil)
  option(vim.wo[win], saved, "foldmethod", max_ts and "manual" or nil)
  history[buf] = next(saved) and saved or nil
end

local function semantic_policy(bufnr, state)
  if _G.is_bigfile(bufnr) then
    if state.semantic == nil then
      state.semantic = vim.lsp.semantic_tokens.is_enabled({ bufnr = bufnr })
    end
    vim.lsp.semantic_tokens.enable(false, { bufnr = bufnr })
  elseif state.semantic ~= nil then
    vim.lsp.semantic_tokens.enable(state.semantic, { bufnr = bufnr })
    state.semantic = nil
  end
end

local function refresh(bufnr)
  classify(bufnr, false)
  local state = buffers[bufnr] or { options = {} }
  buffers[bufnr] = state
  local max_ts = _G.is_bigfile(bufnr, "max_ts")
  if max_ts then
    -- Stopping Treesitter restores legacy syntax; disable it afterwards.
    vim.treesitter.stop(bufnr)
  end
  option(vim.bo[bufnr], state.options, "syntax", max_ts and "off" or nil)
  option(vim.bo[bufnr], state.options, "indentexpr", max_ts and "" or nil)
  semantic_policy(bufnr, state)
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    window_policy(win)
  end
  if state.tier ~= vim.b[bufnr].bigfile_level then
    state.tier = vim.b[bufnr].bigfile_level
    vim.api.nvim_exec_autocmds("User", { pattern = "BigfileChanged", data = { buf = bufnr } })
  end
end

local group = vim.api.nvim_create_augroup("bigfile-optimizations", { clear = true })
vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
  group = group,
  callback = function(ev)
    classify(ev.buf, true)
    local state = buffers[ev.buf] or { options = {} }
    buffers[ev.buf] = state
    semantic_policy(ev.buf, state)
  end,
})
vim.api.nvim_create_autocmd({ "BufReadPost", "FileType", "TextChanged", "TextChangedI", "BufWritePre" }, {
  group = group,
  callback = function(ev)
    refresh(ev.buf)
  end,
})
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function()
    window_policy(vim.api.nvim_get_current_win())
  end,
})
vim.api.nvim_create_autocmd("WinClosed", {
  group = group,
  callback = function(ev)
    windows[tonumber(ev.match)] = nil
  end,
})
vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  callback = function(ev)
    buffers[ev.buf] = nil
    for _, state in pairs(windows) do
      state.history[ev.buf] = nil
    end
  end,
})
