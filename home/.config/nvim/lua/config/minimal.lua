-- Minimal Neovim (no LazyVim, no plugin manager).
-- Active when ~/.local/share/dotfiles/nvim-profile is "minimal" (default).

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.wrap = false
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.termguicolors = true
vim.opt.mouse = ""

require("config.options")
require("config.keymaps")
require("config.autocmds")
