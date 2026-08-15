local M = {}

local function read_profile()
  local path = vim.fn.expand("~/.local/share/dotfiles/nvim-profile")
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local file = io.open(path, "r")
  if not file then
    return nil
  end

  local profile = (file:read("*l") or ""):gsub("%s+", "")
  file:close()

  if profile == "minimal" then
    return nil
  end

  if profile == "lazyvim" or profile == "lazyvim-lite" then
    return profile
  end

  return nil
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
