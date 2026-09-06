# dotfiles

Bash, tmux, nvim, and CLI tools. One `main` branch. Clone to `~/.dotfiles`, pick an installer, run `--all`.

The clone lives at `~/.dotfiles` (hidden). If you clone to `~/dotfiles`, the installer renames it on first run and continues from there.

## Installers

| Script | Profile |
|--------|---------|
| `./devbox.sh` | Ubuntu/Debian development machine (symlinks; keep the clone) |
| `./desktop.sh` | Fedora desktop/development machine (symlinks; keep the clone) |
| `./server.sh` | Server, VPS, VM, or container (copies real files; safe to delete the clone after) |

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

./devbox.sh --all      # Debian/Ubuntu
./desktop.sh --all     # Fedora
./server.sh --all      # light host / CT
```

`--all` is the daily box: configs, packages, bat/fd/zoxide/eza, lazygit, gh, neovim, btop, fzf, tmux plugins, and Nerd Fonts (Cascadia Code + JetBrains Mono, user fonts + fc-cache). Fedora also gets starship. `devbox.sh` and `desktop.sh` also install AI agent rules (Cursor, Codex, Claude Code). `server.sh` is slimmer: configs, apt, neovim; no gitconfig, fzf, zoxide, lazygit, gh, btop, TPM, fonts, fastfetch, or AI rules.

Fetch on a light host: `./server.sh --fetch`. On devbox/desktop: `./install-fetch.sh`.

Want a subset? `./devbox.sh -h`, `./desktop.sh -h`, or `./server.sh -h`. After a devbox/desktop install, copy SSH keys into `~/.ssh/` yourself, then in tmux hit `prefix + Shift + I` once.

Light host: `rm -rf ~/.dotfiles` when you are done. Later upgrades live in `~/.install-scripts/` (`neovim-install-update.sh`, `fastfetch-install-update.sh`).

Refresh AI rules only: `./install-ai-rules.sh`

## Not part of --all

```bash
./install-fetch.sh                      # fastfetch + boxed config + art picker
./server.sh --fetch                     # same fetch on a light host (copies)
./install-ai-rules.sh                   # refresh Cursor/Codex/Claude rules
./lazyvim/install-lazyvim.sh            # LazyVim IDE
./lazyvim-lite/install-lazyvim-lite.sh  # LazyVim, no Mason/LSP/Node
./scripts/nvm-install-update.sh         # Node via nvm
./scripts/lazydocker-install-update.sh
./scripts/alacritty-install-update.sh    # Fedora: dnf. Ubuntu: GitHub source + cargo
./scripts/kitty-install-update.sh        # GitHub Linux tarball (local Kitty binary)
./scripts/kitty-terminfo-install-update.sh   # xterm-kitty terminfo (part of --all; SSH/tmux from Kitty)
./scripts/kitty-image-support-install-update.sh  # optional: ImageMagick + LazyVim snacks image
./scripts/gnome-super-enter-terminal-install-update.sh  # GNOME Super+Enter -> default terminal (skip if no GNOME)
./scripts/avahi-install-update.sh       # hostname.local
./scripts/install-tmux-config.sh        # tmux only; clone can go after
```

Fetch: one boxed layout (`~/.config/fastfetch/config.jsonc`) for `fastfetch`, tmux, and `fetch`. Workstation: `./install-fetch.sh`. Light host: `./server.sh --fetch`. Art: `--art 1` is default, `--art c` is custom. Repo templates: `home/.config/fastfetch/custom-fetch-art.example.txt` and `custom-fetch-padding.example.jsonc`. First `--fetch` copies those to `~/.config/custom-fetch-art.txt` and `~/.config/custom-fetch-padding.jsonc` if missing, then never overwrites. Foreign fastfetch files are backed up before cleanup.

Default nvim is the plain editor. LazyVim is linked only by the lazyvim scripts. See `lazyvim/README.md` if you go that route.

## Day to day

```bash
cd ~/.dotfiles && git pull && ./devbox.sh          # or ./desktop.sh
```

Re-runs overwrite files this repo already manages. Something it did not put there gets one `*.pre-dotfiles` backup. LazyVim is left alone unless you run those scripts.

Prompt is `~/.config/dotfiles/prompt.sh` (custom on Debian, starship on Fedora). `del` is `trash-put`. `rm` is still `rm`.

## Uninstall

Undoes `./devbox.sh`, `./desktop.sh`, and `./server.sh` only. LazyVim and LazyVim-lite are left alone.

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
