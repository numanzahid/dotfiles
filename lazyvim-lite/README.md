# LazyVim-lite

LazyVim look and feel without the IDE stack. Same Tree-sitter CLI install path as full LazyVim, but no Mason, LSP, Node.js, or language IDE extras.

Use this when you want a fast, pretty text editor on servers and VMs, not a language server workstation.

## Install

Prerequisites: run dotfiles base install first (at minimum Neovim):

```bash
./install.sh --neovim
chmod +x lazyvim-lite/*.sh lazyvim-lite/lib/*.sh
./lazyvim-lite/install-lazyvim-lite.sh
```

Switch profiles later:

```bash
./scripts/nvim-profile.sh lazyvim-lite   # this build
./scripts/nvim-profile.sh lazyvim        # full IDE profile
./scripts/nvim-profile.sh none           # plain nvim (nvim-plain config)
./scripts/nvim-profile.sh status
```

## What is removed vs full LazyVim

| Removed | Kept |
|---------|------|
| Mason + LSP servers | LazyVim UI (Snacks, Noice, which-key) |
| nvim-lspconfig | Tree-sitter highlighting, folds, indent |
| conform.nvim (format-on-save) | blink.cmp (buffer/path/snippets only) |
| nvim-lint | Git signs, flash, bufferline, mini.* |
| lazydev.nvim | grug-far, trouble, todo-comments |
| Node.js / nvm requirement | persistence, themes (tokyonight) |
| dotfiles lang extras (TS, Python, Docker, etc.) | treesitter textobjects, ts-autotag |

## System dependencies

Installed by `lazyvim/install-system-deps.sh` (shared with full LazyVim). Same command checks on Debian/Ubuntu and Fedora; see `lazyvim/README.md`.

### User-local binaries

| Binary | Path | Purpose |
|--------|------|---------|
| tree-sitter CLI | `~/.local/bin/tree-sitter` | nvim-treesitter parser install/update |
| fd (compat) | `~/.local/bin/fd` | Debian `fdfind` symlink only when `fd` is missing |

Tree-sitter CLI version: try 0.26.11 first, then fall back to an older prebuilt that executes (see `lazyvim/install-tree-sitter-cli.sh`).

### Not required for lite

- Node.js / npm / nvm
- Mason registry packages
- Python/Perl/Ruby Neovim providers (disabled in dotfiles nvim config)
- Rust / LLVM toolchain

### Recommended (optional)

- Nerd Font (icons in bufferline, which-key)
- `./install.sh --tools` for upstream bat, eza, zoxide (not required by LazyVim-lite itself)

## Neovim plugins

### Plugin manager

| Plugin | Repo |
|--------|------|
| lazy.nvim | folke/lazy.nvim |

### LazyVim core (enabled)

| Plugin | Repo | Role |
|--------|------|------|
| LazyVim | LazyVim/LazyVim | distro config, keymaps, UI integration |
| snacks.nvim | folke/snacks.nvim | explorer, picker, terminal, dashboard |
| noice.nvim | folke/noice.nvim | better cmdline and messages |
| nui.nvim | MunifTanjim/nui.nvim | UI components (Noice dependency) |
| which-key.nvim | folke/which-key.nvim | keymap discovery |
| nvim-treesitter | nvim-treesitter/nvim-treesitter | syntax, folds, indent |
| nvim-treesitter-textobjects | nvim-treesitter/nvim-treesitter-textobjects | function/class motion |
| nvim-ts-autotag | windwp/nvim-ts-autotag | HTML/JSX tag closing |
| blink.cmp | saghen/blink.cmp | completion (no LSP source) |
| friendly-snippets | rafamadriz/friendly-snippets | snippet definitions |
| bufferline.nvim | akinsho/bufferline.nvim | tabline (diagnostics off) |
| lualine.nvim | nvim-lualine/lualine.nvim | statusline |
| gitsigns.nvim | lewis6991/gitsigns.nvim | git gutter |
| flash.nvim | folke/flash.nvim | jump navigation |
| grug-far.nvim | MagicDuck/grug-far.nvim | project search/replace |
| trouble.nvim | folke/trouble.nvim | diagnostics/loclist UI |
| todo-comments.nvim | folke/todo-comments.nvim | TODO/FIXME highlights |
| persistence.nvim | folke/persistence.nvim | session save/restore |
| mini.ai | echasnovski/mini.ai | text objects |
| mini.pairs | echasnovski/mini.pairs | auto-pairs |
| mini.icons | echasnovski/mini.icons | icon sets |
| plenary.nvim | nvim-lua/plenary.nvim | Lua utilities |
| tokyonight.nvim | folke/tokyonight.nvim | default colorscheme |
| catppuccin | catppuccin/nvim | alternate colorscheme |
| ts-comments.nvim | folke/ts-comments.nvim | treesitter-aware comments |

### Dotfiles overrides (enabled)

| File | Role |
|------|------|
| lua/plugins/lazyvim-lite.lua | disable IDE plugins, tune treesitter + blink |
| lua/plugins/dotfiles-tweaks.lua | snacks image off, trash off for headless |
| lua/config/treesitter-path.lua | PATH for tree-sitter CLI |
| lua/config/options.lua | disable python/perl/ruby providers |

### Disabled in lite profile

| Plugin | Repo | Why |
|--------|------|-----|
| mason.nvim | mason-org/mason.nvim | LSP/tool installer |
| mason-lspconfig.nvim | mason-org/mason-lspconfig.nvim | Mason + LSP bridge |
| nvim-lspconfig | neovim/nvim-lspconfig | language servers |
| conform.nvim | stevearc/conform.nvim | format-on-save |
| nvim-lint | mfussenegger/nvim-lint | linter integration |
| lazydev.nvim | folke/lazydev.nvim | LSP types for Lua |

### Not loaded (full LazyVim only)

`lua/config/dotfiles-extras.lua` is imported only when profile is `lazyvim` (typescript, python, json, yaml, toml, tailwind, git, docker).

## Tree-sitter parsers (ensure_installed)

bash, c, css, diff, dockerfile, html, javascript, jsdoc, json, lua, luadoc, markdown, markdown_inline, python, regex, toml, tsx, typescript, vim, vimdoc, xml, yaml

Installed automatically on first sync via nvim-treesitter (same mechanism as full LazyVim).

## Disk footprint (typical)

- LazyVim-lite plugins only: ~80-150 MB (no Mason registry)
- Tree-sitter parsers: ~30-60 MB
- tree-sitter CLI: ~5 MB

Compare to full LazyVim with Mason + Node: often 400 MB-1 GB+ extra.

## Files in this folder

| File | Purpose |
|------|---------|
| install-lazyvim-lite.sh | main installer |
| sync-lazyvim-lite.sh | headless `Lazy! sync` + treesitter preload |
| install.conf | allow-root, apt cleanup |
| lib/common.sh | log prefix + reuse lazyvim helpers |

Shared with `lazyvim/`: system deps, tree-sitter CLI, leftover cleanup, nvim-profile.

## Verify

```bash
nvim --headless "+checkhealth lazy" +qa
nvim --headless "+checkhealth nvim-treesitter" +qa   # may warn on old glibc; see lazyvim README
```

Inside nvim: `:Lazy`, `:LazyHealth`, `:TSInstallInfo`

### Expected health noise on headless servers

| Check | Expected on a CT/SSH host |
|-------|---------------------------|
| nvim-treesitter CLI 0.26.1 | ERROR on bookworm; install shows **WARN (degraded CLI)**; parsers still work |
| snacks.image | Warnings (no kitty/wezterm, no imagemagick) |
| snacks.explorer trash | Warning (permanent delete; dotfiles disables trash helper) |
| vim.provider node | Warning (Node not required for lite) |
| blink_cmp_fuzzy lib | Warning until first completion triggers download |

### Real issues (should be fixed)

- **blink.cmp lazydev error** breaks `:` command hints; fixed in `lua/plugins/lazyvim-lite.lua`
- **lazy invalid spec** for bare `name = "lazyvim-lite-init"`; fixed (use `init.lua` for `vim.g.autoformat`)

After pulling config fixes, restart nvim and run `:Lazy sync`, then `:checkhealth blink.cmp`.
