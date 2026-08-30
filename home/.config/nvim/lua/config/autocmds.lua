-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  pattern = ".env*",
  callback = function()
    vim.bo.filetype = "sh"
    vim.bo.commentstring = "# %s"
  end,
})

-- LazyVim already runs checktime on FocusGained/TermClose/TermLeave. That is
-- not enough in tmux/SSH: focus events often never arrive, so a file changed
-- on disk stays stale until you leave a terminal buffer.
--
-- Unchanged buffer + disk change: autoread reloads.
-- Dirty buffer + disk change: Neovim W12 prompt (keep buffer or load file).
local function should_checktime()
  if vim.fn.getcmdwintype() ~= "" then
    return false
  end
  if vim.bo.buftype ~= "" then
    return false
  end
  local mode = vim.api.nvim_get_mode().mode
  if mode:find("[ct]") then
    return false
  end
  return true
end

local function check_disk()
  if should_checktime() then
    vim.cmd.checktime()
  end
end

local checktime_group = vim.api.nvim_create_augroup("dotfiles_checktime", { clear = true })
local checktime_timer ---@type uv.uv_timer_t?

vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "TermClose", "TermLeave" }, {
  group = checktime_group,
  callback = check_disk,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = checktime_group,
  callback = function(event)
    -- "changed" means the buffer was unmodified and Neovim reloaded it.
    -- "conflict" is the W12 prompt (dirty buffer + disk change); do not
    -- pretend that was a reload.
    if vim.v.fcs_reason ~= "changed" then
      return
    end
    local name = vim.fn.fnamemodify(event.file, ":~")
    vim.notify("Reloaded " .. name .. " (changed on disk)", vim.log.levels.INFO)
  end,
})

local function start_checktime_timer()
  if checktime_timer then
    return
  end
  local timer = vim.uv.new_timer()
  if not timer then
    return
  end
  checktime_timer = timer
  timer:start(1500, 1500, vim.schedule_wrap(check_disk))
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = checktime_group,
    once = true,
    callback = function()
      timer:stop()
      timer:close()
      checktime_timer = nil
    end,
  })
end

if #vim.api.nvim_list_uis() > 0 then
  start_checktime_timer()
else
  vim.api.nvim_create_autocmd("UIEnter", {
    group = checktime_group,
    once = true,
    callback = start_checktime_timer,
  })
end
