# dotfiles

Bash, tmux, nvim, and CLI tools. One `main` branch. Clone it, pick an installer, run `--all`.

The clone lives at `~/.dotfiles` (hidden). If you clone to `~/dotfiles`, the installer renames it on first run and continues from there.

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

./install.sh --all                 # Debian/Ubuntu. Keep the clone. Configs are symlinks.
./install-fedora.sh --all          # Fedora. Same bashrc. dnf or GitHub only, never COPR.
./install-copy/install.sh --all    # Light host / CT. Real files. Safe to delete the clone after.
```

`--all` is the daily box: configs, packages, bat/fd/zoxide/eza, lazygit, gh, neovim, btop, fzf, tmux plugins. Fedora also gets starship. Light host is slimmer (configs, apt, neovim) and skips gitconfig, fzf, zoxide, lazygit, gh, btop, TPM, and fastfetch. Fetch on a light host: `./install-copy/install.sh --fetch`.

Want a subset? `./install.sh -h` (or the fedora/copy script). After a workstation install, copy SSH keys into `~/.ssh/` yourself, then in tmux hit `prefix + Shift + I` once.

Light host: `rm -rf ~/.dotfiles` when you are done. Later upgrades live in `~/.install-scripts/` (`neovim-install-update.sh`, `fastfetch-install-update.sh`).

## Not part of --all

These stay optional on every installer. Run them when you want them.

```bash
./install-fetch.sh                      # fastfetch + boxed config + art picker
./install-copy/install.sh --fetch       # same fetch on a light host (copies)
./install-ai-cli.sh                     # OpenCode, Cursor, Claude Code, Codex
./lazyvim/install-lazyvim.sh            # LazyVim IDE
./lazyvim-lite/install-lazyvim-lite.sh  # LazyVim, no Mason/LSP/Node
./scripts/nvm-install-update.sh         # Node via nvm
./scripts/lazydocker-install-update.sh
./scripts/avahi-install-update.sh       # hostname.local
./scripts/install-tmux-config.sh        # tmux only; clone can go after
```

Fetch: one boxed layout (`~/.config/fastfetch/config.jsonc`) for `fastfetch`, tmux, and `fetch`. Workstation: `./install-fetch.sh`. Light host: `./install-copy/install.sh --fetch` (not part of `--all`). Art: `--art 1` is default, `--art c` is custom. Custom art and padding are local only: `~/.config/custom-fetch-art.txt` and `~/.config/custom-fetch-padding.jsonc`. The banner script applies those on top of `config.jsonc` (`--logo` and `--logo-padding-*`).

Default nvim is the plain editor. LazyVim is linked only by the lazyvim scripts. See `lazyvim/README.md` if you go that route.

## Day to day

```bash
cd ~/.dotfiles && git pull && ./install.sh          # or ./install-fedora.sh
```

Re-runs overwrite files this repo already manages. Something it did not put there gets one `*.pre-dotfiles` backup. LazyVim and AI CLIs are left alone unless you run those scripts.

Prompt is `~/.config/dotfiles/prompt.sh` (custom on Debian, starship on Fedora). `del` is `trash-put`. `rm` is still `rm`.

## Uninstall

Undoes `./install.sh`, `./install-fedora.sh`, and `./install-copy/install.sh` only. LazyVim and LazyVim-lite are left alone.

The installer records dests in `~/.local/share/dotfiles/managed-paths`, originals next to them as `*.pre-dotfiles`, and a journal at `~/.local/share/dotfiles/install-journal.tsv`.

```bash
cd ~/.dotfiles
./uninstall.sh                         # dry-run
./uninstall.sh --apply                 # restore originals, remove what we placed
./uninstall.sh --apply --remove-clone  # also trash ~/.dotfiles
```

Hosts that ran `--all` before this journal existed:

```bash
./uninstall.sh --seed-workstation         # review
./uninstall.sh --seed-workstation --apply
./uninstall.sh                            # review
./uninstall.sh --apply
```

Does not revert locale. Does not `apt autoremove`. Does not touch skipped files (`~/.ssh/config`, a real `prompt.sh`). Does not undo LazyVim or LazyVim-lite (`./lazyvim/install-lazyvim.sh`, `./lazyvim-lite/install-lazyvim-lite.sh`).

Do not commit keys, tokens, `auth.json`, `hosts.yml`, or `.env*`. SSH templates are `home/.ssh/*.example`.
