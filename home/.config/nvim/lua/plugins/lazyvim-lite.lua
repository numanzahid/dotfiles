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
    "saghen/blink.cmp",
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      opts.sources.default = { "path", "snippets", "buffer" }

      opts.sources.providers = opts.sources.providers or {}
      opts.sources.providers.lsp = nil
      opts.sources.providers.lazydev = nil

      if opts.sources.per_filetype and opts.sources.per_filetype.lua then
        opts.sources.per_filetype.lua = { inherit_defaults = true }
      end

      if vim.tbl_get(opts, "completion", "menu", "draw", "treesitter") then
        opts.completion.menu.draw.treesitter = {}
      end

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
