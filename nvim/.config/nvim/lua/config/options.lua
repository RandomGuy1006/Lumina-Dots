vim.g.mapleader = " "
vim.g.autoformat = true

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.updatetime = 200
vim.opt.signcolumn = "yes"

local ok, colors = pcall(require, "config.matugen-colors")
if ok then
  vim.g.lumina_matugen = colors.colors
end
