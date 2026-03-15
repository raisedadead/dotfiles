vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local opt = vim.opt

opt.number = true
opt.relativenumber = true

opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true

opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8

opt.splitbelow = true
opt.splitright = true

opt.updatetime = 250
opt.timeoutlen = 300

vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)

opt.undofile = true

opt.laststatus = 0
opt.showmode = false

opt.fillchars = { eob = " " }

opt.breakindent = true
opt.linebreak = true
opt.smoothscroll = true
opt.shiftround = true

opt.inccommand = "split"
opt.confirm = true
opt.splitkeep = "screen"
opt.virtualedit = "block"
opt.pumheight = 10

opt.list = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
