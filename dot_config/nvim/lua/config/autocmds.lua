local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank
autocmd("TextYankPost", {
  group = augroup("highlight_yank", { clear = true }),
  callback = vim.hl.on_yank,
})

-- Restore cursor position
autocmd("BufReadPost", {
  group = augroup("restore_cursor", { clear = true }),
  callback = function(event)
    local mark = vim.api.nvim_buf_get_mark(event.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(event.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Close certain filetypes with q
autocmd("FileType", {
  group = augroup("close_with_q", { clear = true }),
  pattern = { "help", "man", "qf", "notify", "checkhealth" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true, desc = "Close window" })
  end,
})

-- Trim trailing whitespace on save
autocmd("BufWritePre", {
  group = augroup("trim_whitespace", { clear = true }),
  callback = function()
    if vim.api.nvim_buf_line_count(0) > 10000 then return end
    local save = vim.fn.winsaveview()
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.winrestview(save)
  end,
})

-- Auto-resize splits on VimResized
autocmd("VimResized", {
  group = augroup("resize_splits", { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- Reload files changed outside Neovim
autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = augroup("checktime", { clear = true }),
  callback = function()
    if vim.o.buftype ~= "nofile" then vim.cmd("checktime") end
  end,
})

-- Stop auto-inserting comment leaders on new lines
autocmd("FileType", {
  group = augroup("fix_formatoptions", { clear = true }),
  callback = function()
    vim.opt_local.formatoptions:remove({ "o", "r" })
  end,
})

-- Start terminal in insert mode, hide line numbers
autocmd("TermOpen", {
  group = augroup("term_settings", { clear = true }),
  callback = function()
    vim.cmd("startinsert")
    vim.wo.number = false
    vim.wo.relativenumber = false
  end,
})
