vim.pack.add({
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
  "https://github.com/folke/snacks.nvim",
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/nvim-mini/mini.clue",
  "https://github.com/nvim-mini/mini.surround",
  "https://github.com/stevearc/conform.nvim",
  "https://github.com/xvzc/chezmoi.nvim",
})

require("catppuccin").setup({
  flavour = "mocha",
  transparent_background = true, -- Ghostty supplies the background.
  custom_highlights = function(colors)
    return { LineNr = { fg = colors.overlay0 } }
  end,
})
-- The flavour-specific name avoids Neovim's built-in catppuccin.
vim.cmd.colorscheme("catppuccin-mocha")

require("snacks").setup({
  explorer = { replace_netrw = false },
  picker = {
    ui_select = false,
    sources = { explorer = { jump = { close = true } } },
  },
})

require("chezmoi").setup({
  edit = { watch = false, force = false },
  events = {
    on_open = { notification = { enable = true } },
    on_watch = { notification = { enable = true } },
    on_apply = { notification = { enable = true } },
  },
})

require("mini.clue").setup({
  triggers = { { mode = "n", keys = "<Leader>" } },
  clues = { { mode = "n", keys = "<Leader>c", desc = "+Chezmoi" } },
})
require("mini.surround").setup({
  mappings = {
    add = "gsa",
    delete = "gsd",
    find = "gsf",
    find_left = "gsF",
    highlight = "gsh",
    replace = "gsr",
    update_n_lines = "gsn",
  },
})

require("config.formatting")
