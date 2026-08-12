# dotfiles

Shell, tmux, neovim, and CLI tool configs with install scripts.

## Quick start

On a fresh temp VM or machine:

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh install-deps.sh install-tools.sh install-lazyvim.sh scripts/*.sh
./install.sh --all
```

Copy SSH keys manually (never commit private keys). See `home/.ssh/config.example`.

Optional LazyVim bootstrap (not part of `--all`):

```bash
./install-lazyvim.sh
```

Plain `./install.sh` only symlinks configs into `$HOME`.

## install.sh

| Flag | Action |
|------|--------|
| `--deps` | Base apt packages |
| `--tools` | bat, fd, zoxide, eza, chafa |
| `--lazygit` / `--gh` | lazygit, GitHub CLI |
| `--neovim` | Neovim from GitHub release |
| `--fastfetch` / `--pfetch` | Optional fetch tools |
| `--tpm` / `--fzf` | tmux plugins, fzf |
| `--all` | All of the above (not LazyVim extras) |
| `--dry-run` | Preview only |

After install, open tmux and run `prefix + Shift + I` once for TPM plugins.

Tmux fetch banner (optional): `./scripts/enable-tmux-fetch.sh fastfetch|pfetch|none`

## Updates

```bash
cd ~/dotfiles && git pull && ./install.sh
```

Re-run individual `scripts/*-install-update.sh` files to upgrade tools.

## Layout

```text
dotfiles/
  install.sh install-deps.sh install-tools.sh install-lazyvim.sh
  scripts/
  home/          # symlinked into $HOME
```

## Security

Do not commit: SSH private keys, API tokens, `auth.json`, `hosts.yml`, `.env*`, or plugin caches.

## LazyVim

Merge upstream when needed:

```bash
git remote add upstream https://github.com/LazyVim/starter.git 2>/dev/null || true
git fetch upstream && git merge upstream/main
```

`install-lazyvim.sh` adds nvim apt extras, tree-sitter CLI (source build on older glibc), and parser sync.
