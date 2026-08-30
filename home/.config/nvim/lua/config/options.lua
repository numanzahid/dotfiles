-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Headless/login tools (tree-sitter CLI, etc.) live here; nvim does not load shell rc.
local local_bin = vim.fn.expand("~/.local/bin")
if vim.fn.isdirectory(local_bin) == 1 and not vim.env.PATH:find(local_bin, 1, true) then
  vim.env.PATH = local_bin .. ":" .. vim.env.PATH
end

-- Optional host providers (LazyVim uses blink/LSP, not these).
vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.loaded_node_provider = 0

-- OSC52 clipboard over SSH/tmux:
-- - copy out works (remote -> local clipboard)
-- - paste/read is disabled to avoid hangs

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

-- Keep default registers for normal `p`; avoid OSC52 clipboard READ attempts
vim.opt.clipboard = ""

-- Absolute line numbers (Omarchy preference; LazyVim default is relative).
vim.opt.relativenumber = false

-- Reload from disk when the buffer is unchanged. Conflict prompt when both
-- the buffer and the file have changed (see lua/config/autocmds.lua).
vim.opt.autoread = true
