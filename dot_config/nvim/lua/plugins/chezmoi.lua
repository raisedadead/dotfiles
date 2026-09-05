return {
  "xvzc/chezmoi.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  lazy = false,
  config = function()
    require("chezmoi").setup({
      edit = {
        watch = false,
        force = false,
      },
      events = {
        on_open = { notification = { enable = true } },
        on_watch = { notification = { enable = true } },
        on_apply = { notification = { enable = true } },
      },
    })
  end,
}
