return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  event = { "BufReadPost", "BufNewFile" },
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").install({
      "bash", "c", "css", "diff", "dockerfile",
      "go", "html", "javascript", "json",
      "lua", "luadoc", "markdown", "markdown_inline",
      "python", "query", "regex", "toml", "tsx",
      "typescript", "vim", "vimdoc", "yaml",
    })
  end,
}
