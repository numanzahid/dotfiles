-- Load LazyVim only after ./install-lazyvim.sh sets the profile.
-- Default (./install.sh): minimal Neovim with no plugin downloads.

local function read_profile()
  local path = vim.fn.expand("~/.local/share/dotfiles/nvim-profile")
  if vim.fn.filereadable(path) ~= 1 then
    return "minimal"
  end
  local file = io.open(path, "r")
  if not file then
    return "minimal"
  end
  local profile = file:read("*l") or "minimal"
  file:close()
  profile = profile:gsub("%s+", "")
  if profile == "lazyvim" then
    return "lazyvim"
  end
  return "minimal"
end

if read_profile() == "lazyvim" then
  require("config.lazy")
else
  require("config.minimal")
end
