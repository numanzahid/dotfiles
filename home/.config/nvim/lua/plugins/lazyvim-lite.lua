-- LazyVim-lite: keep the LazyVim editor UX, drop the IDE/LSP stack.
-- Active only when ~/.local/share/dotfiles/nvim-profile contains "lazyvim-lite".

local profile = require("config.nvim-profile")

if not profile.is("lazyvim-lite") then
  return {}
end

local ide_plugins = {
  "mason.nvim",
  "mason-lspconfig.nvim",
  "nvim-lspconfig",
  "conform.nvim",
  "nvim-lint",
  "lazydev.nvim",
}

local disabled = {}
for _, name in ipairs(ide_plugins) do
  disabled[#disabled + 1] = { name, enabled = false, optional = true }
end

return vim.list_extend(disabled, {
  {
    name = "lazyvim-lite-init",
    lazy = false,
    priority = 10002,
    init = function()
      vim.g.autoformat = false
    end,
  },
  {
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.default = { "buffer", "path", "snippets" }
      opts.sources.cmdline = { "buffer", "cmdline" }
      return opts
    end,
  },
  {
    "akinsho/bufferline.nvim",
    opts = function(_, opts)
      opts.options = opts.options or {}
      opts.options.diagnostics = false
      return opts
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts_extend = { "ensure_installed" },
    opts = {
      ensure_installed = {
        "bash",
        "c",
        "css",
        "diff",
        "dockerfile",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "python",
        "regex",
        "toml",
        "tsx",
        "typescript",
        "vim",
        "vimdoc",
        "xml",
        "yaml",
      },
    },
  },
})
