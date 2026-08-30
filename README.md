# dotfiles

Bash, tmux, neovim, and CLI configs. Pick one installer:

| | Workstation | Fedora | Light host |
|---|---|---|---|
| Script | `./install.sh` | `./install-fedora.sh` | `./install-copy/install.sh` |
| Configs | symlinks into `$HOME` | same shared bashrc; starship prompt | real files in `$HOME` |
| Clone | keep it | keep it | safe to delete after install |

Same git branch (`main`) for all three. Distro differences live in the installer, not a fork.

## Workstation

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --all
```

`--all` links configs and installs apt deps (including trash-cli), bat, fd, zoxide, eza, lazygit, gh, neovim, btop, TPM, and fzf.

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

Prompt is `~/.config/dotfiles/prompt.sh` (custom hostname:path on Debian). Fedora uses starship via the same file.

Default nvim is the plain config (`home/.config/nvim-plain`).

Interactive alias: `del` -> `trash-put` (`rm` is unchanged). Agent trash-cli instructions are copied (not linked) to `~/.cursor/rules/use-trash-cli.mdc`, `~/.codex/AGENTS.md`, and `~/.claude/CLAUDE.md`.

## Fedora

Links the same `~/.bashrc` as the workstation (Fedora `/etc/bashrc`, PATH, and `~/.bashrc.d` are in that file). Prompt is a separate symlink, `~/.config/dotfiles/prompt.sh`. Official dnf or GitHub only. Never COPR.

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install-fedora.sh --all
```

`--all` also installs starship from GitHub and points the prompt at it. Switch later:

```bash
ln -sfn ~/dotfiles/home/.config/dotfiles/prompt-custom.sh ~/.config/dotfiles/prompt.sh
ln -sfn ~/dotfiles/home/.config/dotfiles/prompt-starship.sh ~/.config/dotfiles/prompt.sh
```

Static split (edit `install-fedora.sh` if a package falls behind):

- dnf: bat, fd-find, eza, btop, fzf, gh, neovim, plus `--deps`
- GitHub: zoxide, lazygit, starship

`--all` flags: `--deps --tools --lazygit --gh --neovim --btop --tpm --fzf --starship`.

## Light host

For CTs and machines where you do not want to keep this repo:

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install-copy/install.sh --all
```

Then you can `rm -rf ~/dotfiles`. Upgrade later with `~/neovim-install-update.sh` and `~/pfetch-install-update.sh`.

`--all` copies configs, installs apt deps (tmux, htop, git, jq, locale, ...), pfetch, and the same GitHub Neovim as the main installer.

Copied: `.bashrc`, prompt, `.profile`, `.inputrc`, `.tmux.conf` (no TPM; pfetch on new panes), aliases, pfetch config, plain `~/.config/nvim/init.lua`, and `~/.ssh/config` plus `~/.ssh/authorized_keys` if missing.

Not included: gitconfig, fzf, zoxide, eza, lazygit, gh, btop, fastfetch, TPM.

No flags copies configs and still installs pfetch if `git` and `jq` are present (no apt, no nvim binary).

Tmux only: `./scripts/install-tmux-config.sh`

## Optional extras

Not part of `--all` on any installer:

```bash
./lazyvim/install-lazyvim.sh              # LazyVim IDE (Debian/Ubuntu and Fedora)
./lazyvim-lite/install-lazyvim-lite.sh    # LazyVim editor only (no Mason/LSP/Node)
./install-fetch.sh                        # tmux banner: none / fastfetch / pfetch / both
./install-ai-cli.sh                       # OpenCode, Cursor, Claude Code, Codex
./scripts/nvm-install-update.sh           # Node via nvm
```

See `lazyvim/README.md` and `lazyvim-lite/README.md`.

## Updates

```bash
cd ~/dotfiles && git pull && ./install.sh           # Debian/Ubuntu
cd ~/dotfiles && git pull && ./install-fedora.sh    # Fedora
```

After pulling a LazyVim lockfile or nvim lua change: `./lazyvim/sync-lazyvim.sh` (full `./lazyvim/install-lazyvim.sh` only on first setup or when deps/extras changed). See `lazyvim/README.md`.

Re-runs overwrite configs the installer already manages (including files you edited). A foreign file is backed up once as `*.pre-dotfiles`. An existing fetch banner, LazyVim nvim config, and AI CLIs are not reset.

Upgrade one tool with `./scripts/<name>-install-update.sh`.

## Layout

```text
install.sh            symlink installer (Debian/Ubuntu; keep the clone)
install-fedora.sh     symlink installer (Fedora; shared bashrc, starship prompt)
install-copy/         copy installer (clone can be deleted)
install-fetch.sh
install-ai-cli.sh
lazyvim/   lazyvim-lite/
scripts/              per-tool GitHub installers
home/                 source configs
  .config/dotfiles/prompt-*.sh  custom vs starship; linked as prompt.sh
  .config/nvim-plain/ linked by ./install.sh and ./install-fedora.sh
  .config/nvim/       LazyVim; linked only by lazyvim scripts
```

## Security

Do not commit SSH private keys, tokens, `auth.json`, `hosts.yml`, `.env*`, or plugin caches.
`home/.ssh/config.example` and `home/.ssh/authorized_keys.example` are the SSH templates. Real keys stay out of git.
