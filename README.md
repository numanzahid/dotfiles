# dotfiles

Shell, tmux, neovim, and CLI tool configs with install scripts.

## Quick start

On a fresh temp VM or machine:

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh install-deps.sh install-tools.sh install-fetch.sh install-ai-cli.sh lazyvim/*.sh lazyvim/lib/*.sh scripts/*.sh
./install.sh --all
```

Copy SSH keys manually (never commit private keys). See `home/.ssh/config.example`.

Optional LazyVim bootstrap (not part of `--all`):

```bash
./lazyvim/install-lazyvim.sh              # full IDE profile
./lazyvim-lite/install-lazyvim-lite.sh    # editor-only (no Mason/LSP/Node)
```

Optional fetch banner (not part of `--all`):

```bash
./install-fetch.sh              # prompt: none / fastfetch / pfetch / both
./install-fetch.sh fastfetch    # install and enable fastfetch
./install-fetch.sh both         # install both; keep current banner if set
./install-fetch.sh none         # disable banner
```

Optional AI coding CLIs (not part of `--all`):

```bash
./install-ai-cli.sh             # prompt per tool
./install-ai-cli.sh all         # OpenCode, Cursor, Claude Code, Codex
./install-ai-cli.sh claude opencode
```

Official sources:

| Tool | Installer |
|------|-----------|
| OpenCode | `https://opencode.ai/install` |
| Cursor CLI (`agent`) | `https://cursor.com/install` |
| Claude Code | `https://claude.ai/install.sh` |
| Codex | `https://chatgpt.com/codex/install.sh` |

Without those scripts, `nvim` uses the plain editor config (`home/.config/nvim-plain`).
`./install.sh` never links or resets LazyVim, never changes an existing fetch banner,
and never installs AI CLIs. Re-running `--all` leaves those extras untouched.

## install.sh

| Flag | Action |
|------|--------|
| `--deps` | Base apt packages |
| `--tools` | bat, fd, zoxide, eza |
| `--lazygit` / `--gh` | lazygit, GitHub CLI |
| `--neovim` | Neovim from GitHub release |
| `--tpm` / `--fzf` | tmux plugins, fzf |
| `--all` | Base bootstrap (no LazyVim, no fetch banner prompt) |
| `--dry-run` | Preview only |

After install, open tmux and run `prefix + Shift + I` once for TPM plugins.

Tmux fetch banner (separate from `--all`):

```bash
./install-fetch.sh
```

## Updates

```bash
cd ~/dotfiles && git pull && ./install.sh
```

Re-run individual `scripts/*-install-update.sh` files to upgrade tools (bat, fd, nvm, neovim, etc.).

Node.js only:

```bash
./scripts/nvm-install-update.sh
```

## Layout

```text
dotfiles/
  install.sh install-deps.sh install-tools.sh install-fetch.sh install-ai-cli.sh
  lazyvim/            # full LazyVim installer (owns LazyVim nvim link)
  lazyvim-lite/       # editor-only LazyVim installer
  scripts/
  home/               # symlinked into $HOME
    .config/nvim-plain/   # plain editor rules (linked by install.sh)
    .config/nvim/         # LazyVim config (linked only by lazyvim scripts)
```

## Security

Do not commit: SSH private keys, API tokens, `auth.json`, `hosts.yml`, `.env*`, or plugin caches.

## LazyVim

See `lazyvim/README.md` for the lean installer (prebuilt Tree-sitter CLI, no Rust/LLVM).

Merge upstream starter config when needed:

```bash
git remote add upstream https://github.com/LazyVim/starter.git 2>/dev/null || true
git fetch upstream && git merge upstream/main
```
