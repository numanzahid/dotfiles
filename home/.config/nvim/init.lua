-- Load LazyVim after ./lazyvim/install-lazyvim.sh or ./lazyvim-lite/install-lazyvim-lite.sh.
-- Default (./install.sh): minimal Neovim with no plugin downloads.

local profile = require("config.nvim-profile")

if profile.is_lazyvim() then
  require("config.lazy")
else
  require("config.minimal")
end
