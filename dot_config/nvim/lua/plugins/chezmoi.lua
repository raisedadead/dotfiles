return {
  "xvzc/chezmoi.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  lazy = false,
  config = function()
    require("chezmoi").setup({
      edit = {
        watch = true,
        force = false,
      },
      events = {
        on_open = { notification = { enable = true } },
        on_watch = { notification = { enable = true } },
        on_apply = { notification = { enable = true } },
      },
    })
  end,
  init = function()
    vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
      pattern = { os.getenv("HOME") .. "/.dotfiles/*" },
      callback = function(ev)
        vim.schedule(function()
          require("chezmoi.commands.__edit").watch(ev.buf)
        end)
      end,
    })
  end,
}
