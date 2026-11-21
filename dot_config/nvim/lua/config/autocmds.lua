-- Stop auto-inserting comment leaders on new lines.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("fix_formatoptions", { clear = true }),
  callback = function()
    vim.opt_local.formatoptions:remove({ "o", "r" })
  end,
})

-- Trim trailing whitespace on save.
-- Keep this separate from Conform so it doesn't mask LSP formatting fallback.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("trim_whitespace", { clear = true }),
  callback = function()
    local filetypes = {
      "sh",
      "zsh",
      "lua",
      "python",
      "go",
      "rust",
      "javascript",
      "javascriptreact",
      "typescript",
      "typescriptreact",
      "json",
      "jsonc",
      "toml",
      "yaml",
      "terraform",
      "css",
      "html",
      "sql",
      "c",
      "cpp",
      "vim",
      "xml",
      "zig",
    }
    if
      not vim.tbl_contains(filetypes, vim.bo.filetype)
      or vim.bo.buftype ~= ""
      or not vim.bo.modifiable
      or vim.bo.binary
      or vim.g.autoformat == false
      or vim.b.autoformat == false
      or vim.api.nvim_buf_line_count(0) > 10000
    then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})
