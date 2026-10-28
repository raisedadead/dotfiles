return {
  "Tim4c/tuios-nvim-navigator",
  lazy = false,
  cond = (vim.env.TUIOS_SESSION or "") ~= "" and vim.env.TMUX == nil,
  opts = {
    keymaps = { left = "<A-H>", down = "<A-J>", up = "<A-K>", right = "<A-L>" },
  },
}
