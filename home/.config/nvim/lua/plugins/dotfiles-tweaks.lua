-- Dotfiles tweaks for headless / SSH / tmux setups.
-- snacks.image stays off unless ~/.config/dotfiles/image-support.enabled exists
-- (./scripts/kitty-image-support-install-update.sh). That file is named so it
-- loads before this one; only skip image here when the flag is missing.

local image_support = vim.fn.filereadable(vim.fn.expand("~/.config/dotfiles/image-support.enabled")) == 1

local snacks_opts = {
  explorer = {
    -- Permanent delete when no desktop trash helper exists (typical on CTs).
    trash = { enabled = false },
  },
}
if not image_support then
  snacks_opts.image = { enabled = false }
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      news = {
        lazyvim = false,
        neovim = false,
      },
    },
  },
  {
    "folke/snacks.nvim",
    opts = snacks_opts,
  },
}
