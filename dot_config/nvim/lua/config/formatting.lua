-- Reuse CLI tools already installed by Mason without loading its plugin.
-- System and project-local executables take precedence.
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if vim.fn.isdirectory(mason_bin) == 1 then
  vim.env.PATH = vim.env.PATH .. (vim.fn.has("win32") == 1 and ";" or ":") .. mason_bin
end

local oxfmt = { "oxfmt" }
local sqlfluff = { "sqlfluff" }
local terraform = { "terraform_fmt" }

require("conform").setup({
  default_format_opts = { lsp_format = "fallback", timeout_ms = 3000 },
  format_on_save = function(buf)
    if vim.g.autoformat ~= false and vim.b[buf].autoformat ~= false then
      return {}
    end
  end,
  formatters_by_ft = {
    astro = oxfmt,
    fish = { "fish_indent" },
    go = { "goimports", "gofumpt" },
    hcl = { "packer_fmt" },
    javascript = oxfmt,
    javascriptreact = oxfmt,
    json = oxfmt,
    jsonc = oxfmt,
    lua = { "stylua" },
    mysql = sqlfluff,
    plsql = sqlfluff,
    python = { "ruff_format" },
    sh = { "shfmt" },
    sql = sqlfluff,
    svelte = oxfmt,
    terraform = terraform,
    ["terraform-vars"] = terraform,
    tf = terraform,
    typescript = oxfmt,
    typescriptreact = oxfmt,
    vue = oxfmt,
    zig = { "zigfmt" },
  },
  formatters = {
    sqlfluff = { args = { "format", "--dialect=ansi", "-" } },
  },
})
