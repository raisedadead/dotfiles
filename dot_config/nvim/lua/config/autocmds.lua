-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Stop auto-inserting comment leaders on new lines.
-- LazyVim sets a global formatoptions of "jcroqlnt", which keeps both `r` and `o`.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("fix_formatoptions", { clear = true }),
  callback = function()
    vim.opt_local.formatoptions:remove({ "o", "r" })
  end,
})

-- Trim trailing whitespace on save.
-- Deliberately an autocmd rather than a conform `formatters_by_ft["_"]` entry:
-- conform treats any resolved formatter as primary, and
-- `conform/init.lua:640-648` only falls through to the LSP when there are none,
-- so a catch-all entry would suppress LazyVim's LSP format-on-save for every
-- filetype without an explicit conform formatter. This composes instead.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("trim_whitespace", { clear = true }),
  callback = function()
    if vim.api.nvim_buf_line_count(0) > 10000 then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})
