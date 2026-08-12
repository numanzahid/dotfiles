-- LazyVim / Neovim extras for headless SSH + tmux setups.
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {
        "bash",
        "regex",
      },
    },
  },
}
