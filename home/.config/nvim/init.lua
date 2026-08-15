-- LazyVim profiles: run ./lazyvim/install-lazyvim.sh or ./lazyvim-lite/install-lazyvim-lite.sh
-- No profile file = plain Neovim (stock + small dotfiles tweaks in config/plain.lua).

local profile = require("config.nvim-profile")

if profile.is("lazyvim-lite") then
  vim.g.autoformat = false
end

if profile.is_lazyvim() then
  require("config.lazy")
else
  require("config.plain")
end
