-- LazyVim config tree. Linked to ~/.config/nvim only by:
--   ./lazyvim/install-lazyvim.sh or ./lazyvim-lite/install-lazyvim-lite.sh
-- Main ./install.sh never links this tree. Plain editor rules live in nvim-plain/.

local profile = require("config.nvim-profile")

if profile.is("lazyvim-lite") then
  vim.g.autoformat = false
end

if profile.is_lazyvim() then
  require("config.lazy")
else
  require("config.plain")
end
