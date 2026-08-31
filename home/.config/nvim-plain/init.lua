-- Plain Neovim editor rules (no LazyVim, no plugin manager).
-- Linked by ./install.sh. Copied by ./install-copy/install.sh.
-- LazyVim scripts replace this with the LazyVim config.

vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.signcolumn = "yes"
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.backspace = { "indent", "eol", "start" }
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.splitbelow = true
vim.opt.splitright = true
vim.opt.termguicolors = true
vim.opt.mouse = ""
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.confirm = true
vim.opt.autoread = true

local state = vim.fn.stdpath("state")
vim.fn.mkdir(state .. "/undo", "p")
vim.fn.mkdir(state .. "/swap", "p")
vim.opt.undofile = true
vim.opt.undodir = { state .. "/undo//" }
vim.opt.directory = { state .. "/swap//" }
vim.opt.backup = false
vim.opt.writebackup = false

local local_bin = vim.fn.expand("~/.local/bin")
if vim.fn.isdirectory(local_bin) == 1 and not vim.env.PATH:find(local_bin, 1, true) then
  vim.env.PATH = local_bin .. ":" .. vim.env.PATH
end

vim.g.loaded_python3_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3

if vim.fn.executable("rg") == 1 then
  vim.opt.grepprg = "rg --vimgrep --smart-case"
  vim.opt.grepformat = "%f:%l:%c:%m"
end

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
vim.opt.clipboard = ""

vim.keymap.set(
  { "n", "v" },
  "<leader>y",
  '"+y',
  { noremap = true, silent = true, desc = "Yank to system clipboard (+)" }
)
vim.keymap.set("n", "<leader>Y", '"+yy', { noremap = true, silent = true, desc = "Yank line to system clipboard (+)" })
-- Same idea as LazyVim: Esc clears search highlight (insert, normal, select).
vim.keymap.set({ "i", "n", "s" }, "<Esc>", function()
  vim.cmd("nohlsearch")
  return "<Esc>"
end, { expr = true, silent = true, desc = "Escape and Clear hlsearch" })

vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  pattern = ".env*",
  callback = function()
    vim.bo.filetype = "sh"
    vim.bo.commentstring = "# %s"
  end,
})

vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
  end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(event)
    local buf = event.buf
    if vim.bo[buf].buftype ~= "" then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local lcount = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Same idea as LazyVim dotfiles: autoread + checktime.
-- Unchanged buffer + disk change: reload. Dirty + disk change: W12 prompt.
-- Timer covers tmux/SSH where FocusGained often never arrives.
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

local checktime_group = vim.api.nvim_create_augroup("dotfiles_plain_checktime", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "TermClose", "TermLeave" }, {
  group = checktime_group,
  callback = check_disk,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = checktime_group,
  callback = function(event)
    if vim.v.fcs_reason ~= "changed" then
      return
    end
    vim.notify("Reloaded " .. vim.fn.fnamemodify(event.file, ":~") .. " (changed on disk)", vim.log.levels.INFO)
  end,
})

local checktime_timer ---@type uv.uv_timer_t?

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
