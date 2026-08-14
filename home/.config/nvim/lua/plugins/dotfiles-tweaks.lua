-- Dotfiles tweaks for headless / SSH / tmux setups (no GUI trash, no kitty images).

return {
  {
    "folke/snacks.nvim",
    opts = {
      image = { enabled = false },
      explorer = {
        -- Permanent delete when no desktop trash helper exists (typical on CTs).
        trash = { enabled = false },
      },
    },
  },
}
