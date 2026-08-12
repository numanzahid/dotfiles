-- Prefer a working tree-sitter CLI over Mason's prebuilt binary (broken on older glibc).
local M = {}

local LOCAL_BIN = vim.fn.expand("~/.local/bin")
local LOCAL_TS = LOCAL_BIN .. "/tree-sitter"
local MASON_BIN = vim.fn.expand("~/.local/share/nvim/mason/bin")
local MASON_TS = MASON_BIN .. "/tree-sitter"

---@param bin string
---@return boolean
local function tree_sitter_works(bin)
  if bin == "" or vim.fn.executable(bin) ~= 1 then
    return false
  end
  vim.fn.system({ bin, "--version" })
  return vim.v.shell_error == 0
end

---@return boolean
function M.needs_fix()
  local active = vim.fn.exepath("tree-sitter")
  if active ~= "" and tree_sitter_works(active) then
    return false
  end

  -- Active binary is missing or broken; fix only if ~/.local/bin has a working build
  -- and Mason's prebuilt copy is the usual culprit on older glibc.
  return vim.fn.executable(MASON_TS) == 1
    and not tree_sitter_works(MASON_TS)
    and tree_sitter_works(LOCAL_TS)
end

function M.apply_if_needed()
  if not M.needs_fix() then
    return
  end

  if vim.env.PATH:find(LOCAL_BIN .. ":", 1, true) ~= 1 then
    vim.env.PATH = LOCAL_BIN .. ":" .. vim.env.PATH
  end

  if vim.env.PATH:find(MASON_BIN .. ":", 1, true) then
    vim.env.PATH = vim.env.PATH:gsub(MASON_BIN .. ":", "", 1)
  end
end

function M.setup()
  -- Mason adjusts PATH during plugin startup; re-check after Lazy finishes.
  vim.api.nvim_create_autocmd("User", {
    pattern = "LazyDone",
    once = true,
    callback = function()
      M.apply_if_needed()
    end,
  })
end

return M
