-- Basic autocommands (non-plugin)

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
  callback = function()
    (vim.hl.hl_op or vim.hl.on_yank)()
  end,
})

-- Close certain windows with 'q'
vim.api.nvim_create_autocmd("FileType", {
  desc = "Close certain filetypes with 'q'",
  group = vim.api.nvim_create_augroup("close-with-q", { clear = true }),
  pattern = { "help", "qf", "checkhealth", "man", "lspinfo", "startuptime" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- Auto-create directories when saving
vim.api.nvim_create_autocmd("BufWritePre", {
  desc = "Auto-create directories when saving",
  group = vim.api.nvim_create_augroup("auto-create-dir", { clear = true }),
  callback = function(event)
    if event.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Check if file changed outside vim
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  desc = "Check if files changed outside vim",
  group = vim.api.nvim_create_augroup("checktime", { clear = true }),
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

local function clean_invalid_neotree_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.fn.bufname(buf)
    local is_neotree_buffer = name:match("^neo%-tree [^ ]+ %[%d+%]$")
    local has_neotree_state = pcall(vim.api.nvim_buf_get_var, buf, "neo_tree_source")

    if is_neotree_buffer and not has_neotree_state then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

-- Session restore (mini.sessions) can bring back Neo-tree's named special
-- buffers before the lazy-loaded Neo-tree plugin has registered its own
-- session cleanup hook.
vim.api.nvim_create_autocmd("SessionLoadPost", {
  desc = "Clean stale Neo-tree buffers after session restore",
  group = vim.api.nvim_create_augroup("clean-restored-neotree-buffers", { clear = true }),
  callback = clean_invalid_neotree_buffers,
})
