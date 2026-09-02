-- Dotfiles tweaks: snacks image (Kitty graphics), explorer trash off on headless hosts.

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
    opts = {
      image = {
        enabled = true,
        doc = {
          enabled = true,
          inline = true,
          float = true,
        },
      },
      explorer = {
        -- Permanent delete when no desktop trash helper exists (typical on CTs).
        trash = { enabled = false },
      },
    },
  },
}
