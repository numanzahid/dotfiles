-- Plain Neovim editor rules (no LazyVim, no plugin manager).
-- Linked by ./install.sh. LazyVim scripts replace this with the LazyVim config.

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

local local_bin = vim.fn.expand("~/.local/bin")
if vim.fn.isdirectory(local_bin) == 1 and not vim.env.PATH:find(local_bin, 1, true) then
  vim.env.PATH = local_bin .. ":" .. vim.env.PATH
end

vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

local osc52 = require("vim.ui.clipboard.osc52")
vim.g.clipboard = {
  name = "OSC52 copy-only",
  copy = {
    ["+"] = osc52.copy("+"),
    ["*"] = osc52.copy("*"),
  },
  paste = {
    ["+"] = function()
      return {}
    end,
    ["*"] = function()
      return {}
    end,
  },
}
vim.opt.clipboard = ""

vim.keymap.set(
  { "n", "v" },
  "<leader>y",
  '"+y',
  { noremap = true, silent = true, desc = "Yank to system clipboard (+)" }
)
vim.keymap.set("n", "<leader>Y", '"+yy', { noremap = true, silent = true, desc = "Yank line to system clipboard (+)" })

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  pattern = ".env*",
  callback = function()
    vim.bo.filetype = "sh"
    vim.bo.commentstring = "# %s"
  end,
})
