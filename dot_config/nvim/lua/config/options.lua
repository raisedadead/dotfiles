-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

opt.scrolloff = 8 -- LazyVim: 4
opt.inccommand = "split" -- LazyVim: "nosplit" — preview :s in a split
opt.breakindent = true -- keep indent when LazyVim force-wraps text/markdown/gitcommit
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" } -- LazyVim leaves nvim's default
