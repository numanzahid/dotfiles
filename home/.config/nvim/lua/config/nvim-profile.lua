local M = {}

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
  return profile:gsub("%s+", "")
end

function M.current()
  return read_profile()
end

function M.is(name)
  return read_profile() == name
end

function M.is_lazyvim()
  local profile = read_profile()
  return profile == "lazyvim" or profile == "lazyvim-lite"
end

return M
