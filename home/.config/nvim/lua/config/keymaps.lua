-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Copy to local OS clipboard register (+) using OSC52
vim.keymap.set(
  { "n", "v" },
  "<leader>y",
  '"+y',
  { noremap = true, silent = true, desc = "Yank to system clipboard (+)" }
)
vim.keymap.set("n", "<leader>Y", '"+yy', { noremap = true, silent = true, desc = "Yank line to system clipboard (+)" })
