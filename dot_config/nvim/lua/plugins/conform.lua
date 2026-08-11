return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      -- Fallback for filetypes with no real formatter: trim trailing whitespace
      -- on save, which LazyVim's autoformat alone does not do.
      ["_"] = { "trim_whitespace" },
    },
  },
}
