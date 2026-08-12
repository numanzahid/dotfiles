-- LazyVim / Neovim extras for headless SSH + tmux setups.
return {
  {
    "tree-sitter-path-fix",
    lazy = false,
    priority = 10000,
    init = function()
      local local_bin = vim.fn.expand("~/.local/bin")
      vim.env.PATH = local_bin .. ":" .. vim.env.PATH

      local mason_bin = vim.fn.expand("~/.local/share/nvim/mason/bin")
      local mason_ts = mason_bin .. "/tree-sitter"
      if vim.fn.executable(mason_ts) == 1 then
        vim.fn.system({ mason_ts, "--version" })
        if vim.v.shell_error ~= 0 then
          vim.env.PATH = vim.env.PATH:gsub(mason_bin .. ":", "", 1)
        end
      end
    end,
  },
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
