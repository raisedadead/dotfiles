vim.g.mapleader = " "
vim.g.maplocalleader = " "

local opt = vim.opt

opt.scrolloff = 8
opt.inccommand = "split"
opt.breakindent = true
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.list = true
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.undofile = true
opt.splitbelow = true
opt.splitright = true
