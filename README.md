# dotfiles

Shell, tmux, neovim, and CLI tool configs with install scripts.

## Quick start

On a fresh temp VM or machine:

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh install-deps.sh install-tools.sh lazyvim/*.sh lazyvim/lib/*.sh scripts/*.sh
./install.sh --all
```

Copy SSH keys manually (never commit private keys). See `home/.ssh/config.example`.

Optional LazyVim bootstrap (not part of `--all`):

```bash
./lazyvim/install-lazyvim.sh              # full IDE profile
./lazyvim-lite/install-lazyvim-lite.sh    # editor-only (no Mason/LSP/Node)
```

Without those scripts, `nvim` uses a minimal config only (no LazyVim download).

Plain `./install.sh` only symlinks configs into `$HOME`.

## install.sh

| Flag | Action |
|------|--------|
| `--deps` | Base apt packages |
| `--tools` | bat, fd, zoxide, eza |
| `--lazygit` / `--gh` | lazygit, GitHub CLI |
| `--neovim` | Neovim from GitHub release |
| `--fastfetch` / `--pfetch` | Install one fetch tool + enable tmux banner |
| `--fetch MODE` | Set tmux fetch: `none`, `fastfetch`, or `pfetch` (no prompt) |
| `--tpm` / `--fzf` | tmux plugins, fzf |
| `--all` | Base bootstrap; prompts for tmux fetch banner |
| `--dry-run` | Preview only |

After install, open tmux and run `prefix + Shift + I` once for TPM plugins.

Tmux fetch banner: prompted during `./install.sh --all`, or run:

```bash
./scripts/setup-tmux-fetch.sh
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
  install.sh install-deps.sh install-tools.sh
  lazyvim/       # lean LazyVim installer
  scripts/
  home/          # symlinked into $HOME
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
