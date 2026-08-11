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
