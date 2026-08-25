# dotfiles

Bash, tmux, neovim, and CLI configs. Pick one installer:

| | Workstation | Light host |
|---|---|---|
| Script | `./install.sh` | `./install-copy/install.sh` |
| Configs | symlinks into `$HOME` | real files in `$HOME` |
| Clone | keep it | safe to delete after install |

## Workstation

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --all
```

`--all` links configs and installs apt deps, bat, fd, zoxide, eza, lazygit, gh, neovim, btop, TPM, and fzf.

It does not install LazyVim, fetch banners, or AI CLIs. Re-running `--all` leaves those extras alone.

| Flag | Action |
|------|--------|
| `--deps` | apt packages + locale |
| `--tools` | bat, fd, zoxide, eza |
| `--lazygit` / `--gh` | lazygit, GitHub CLI |
| `--neovim` | Neovim from GitHub (`/usr/local/bin/nvim`) |
| `--btop` | btop from GitHub |
| `--tpm` / `--fzf` | tmux plugin manager, fzf |
| `--all` | all of the above |
| `--dry-run` | print actions only |

After install: copy SSH keys into `~/.ssh/` yourself, then in tmux press `prefix + Shift + I` once.

Default nvim is the plain config (`home/.config/nvim-plain`).

## Light host

For CTs and machines where you do not want to keep this repo:

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install-copy/install.sh --all
```

Then you can `rm -rf ~/dotfiles`. Upgrade later with `~/neovim-install-update.sh` and `~/pfetch-install-update.sh`.

`--all` copies configs, installs apt deps (tmux, htop, git, jq, locale, ...), pfetch, and the same GitHub Neovim as the main installer.

Copied: `.bashrc`, `.profile`, `.inputrc`, `.tmux.conf` (no TPM; pfetch on new panes), aliases, pfetch config, plain `~/.config/nvim/init.lua`, and `~/.ssh/config` plus `~/.ssh/authorized_keys` if missing.

Not included: gitconfig, fzf, zoxide, eza, lazygit, gh, btop, fastfetch, TPM.

No flags copies configs and still installs pfetch if `git` and `jq` are present (no apt, no nvim binary).

Tmux only: `./scripts/install-tmux-config.sh`

## Optional extras

Not part of either `--all`:

```bash
./lazyvim/install-lazyvim.sh              # LazyVim IDE
./lazyvim-lite/install-lazyvim-lite.sh    # LazyVim editor only (no Mason/LSP/Node)
./install-fetch.sh                        # tmux banner: none / fastfetch / pfetch / both
./install-ai-cli.sh                       # OpenCode, Cursor, Claude Code, Codex
./scripts/nvm-install-update.sh           # Node via nvm
```

See `lazyvim/README.md` and `lazyvim-lite/README.md`.

## Updates

```bash
cd ~/dotfiles && git pull && ./install.sh
```

Re-runs overwrite configs the installer already manages (including files you edited). A foreign file is backed up once as `*.pre-dotfiles`. An existing fetch banner, LazyVim nvim config, and AI CLIs are not reset.

Upgrade one tool with `./scripts/<name>-install-update.sh`.

## Layout

```text
install.sh            symlink installer (keep the clone)
install-copy/         copy installer (clone can be deleted)
install-fetch.sh
install-ai-cli.sh
lazyvim/   lazyvim-lite/
scripts/              per-tool GitHub installers
home/                 source configs
  .config/nvim-plain/ linked by ./install.sh
  .config/nvim/       LazyVim; linked only by lazyvim scripts
```

## Security

Do not commit SSH private keys, tokens, `auth.json`, `hosts.yml`, `.env*`, or plugin caches.
`home/.ssh/config.example` and `home/.ssh/authorized_keys.example` are the SSH templates. Real keys stay out of git.
