# dotfiles

Bash, tmux, nvim, and CLI tools. One `main` branch. Clone to `~/.dotfiles`, run the installer for your OS, then use `dotfiles` day to day.

The clone lives at `~/.dotfiles` (hidden). If you clone to `~/dotfiles`, the installer renames it on first run and continues from there.

## Installers (first time)

| Script | Profile |
|--------|---------|
| `./devbox.sh` | Ubuntu/Debian development machine (symlinks; keep the clone) |
| `./desktop.sh` | Fedora desktop/development machine (symlinks; keep the clone) |
| `./server.sh` | Server, VPS, VM, or container (copies real files; safe to delete the clone after) |

```bash
git clone git@github.com:numanzahid/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

./devbox.sh      # Debian/Ubuntu full install
./desktop.sh     # Fedora full install
./server.sh      # light host / CT full install
```

Each script does a **full install** by default: configs, packages, CLI tools, fonts, tmux TPM, and AI agent rules (devbox/desktop). No `--all` flag.

**devbox/desktop** includes: bat, fd, zoxide, eza, lazygit, gh, neovim, btop, gdu, fzf, tldr, nerd fonts, TPM.

**server** is slimmer: copied configs (including `.gitconfig`), apt packages, neovim, gdu (no fzf, zoxide, lazygit, gh, btop, tldr, TPM, fonts).

Installer options (all profiles):

```bash
./devbox.sh --configs-only    # link/copy configs only
./devbox.sh --software-only   # software only
./devbox.sh --dry-run         # preview
```

Single-tool upgrades: `./scripts/<tool>-install-update.sh`

## dotfiles command

Registered on PATH as `dotfiles` after the first install.

```bash
dotfiles update                 # pull repo, refresh configs, update stale software
dotfiles update --config-only   # pull repo and refresh configs only
dotfiles update --force         # discard repo changes, pull, full reinstall
dotfiles status                 # profile, nvim, fetch, versions, last updated
dotfiles install lazyvim        # optional LazyVim profile
dotfiles install lazyvim-lite   # optional LazyVim lite
dotfiles install fetch          # fastfetch banner (interactive art picker)
```

Run `tldr` (no args) to fuzzy-pick a page, or `tldr dotfiles` for the dotfiles cheat sheet (`share/tldr/`).

**update** always re-links configs. Software is skipped when updated within the last 30 days (except `--force`).

If the repo has local changes, **update** shows a diff and asks before discarding.

## Optional extras

Not part of the main install scripts:

```bash
dotfiles install fetch
dotfiles install lazyvim
dotfiles install lazyvim-lite
./install-ai-rules.sh
./scripts/nvm-install-update.sh
./scripts/alacritty-install-update.sh
./scripts/kitty-install-update.sh
```

See [`SHORTCUTS.md`](SHORTCUTS.md) for shell aliases, fzf, and tmux keys.

## Uninstall

```bash
dotfiles uninstall
# or from the clone:
cd ~/.dotfiles && ./uninstall.sh
```

Prompts for:

1. **Dry run** -- show `+` lines, change nothing (default)
2. **Uninstall** -- restore configs, remove journaled tools, keep clone and journal
3. **Purge** -- uninstall plus trash `~/.dotfiles`, `~/.local/share/dotfiles`, and server CLI copy

Pre-journal hosts are auto-seeded on uninstall/purge. Non-interactive: `DOTFILES_UNINSTALL_MODE=uninstall` or `purge`.

Remove LazyVim completely (plugin data; switches nvim back to nvim-plain):

```bash
dotfiles uninstall lazyvim
```

Remove one dotfiles-managed tool (binary, packages, journaled files):

```bash
dotfiles uninstall lazygit
dotfiles uninstall --list
# or directly:
./scripts/lazygit-install-update.sh --uninstall
```

Each install script owns its `--uninstall` logic (journal + known paths).

## Install journal

Each install records actions in `~/.local/share/dotfiles/install-journal.tsv`:

`timestamp<TAB>kind<TAB>path<TAB>extra`

Uninstall reads the journal to restore configs and remove tools. Kinds:

| Kind | Recorded by | Uninstall action |
|------|-------------|------------------|
| `link` / `copy` | devbox, server, fetch, AI rules, terminals | Restore from `*.pre-dotfiles` or remove our file |
| `binary` | GitHub release scripts, kitty, alacritty | Remove binary or install tree |
| `git-clone` | fzf, tpm | Remove clone directory |
| `package-new` | install-deps (only packages that were missing) | `apt`/`dnf` remove |
| `symlink` / `opt-tree` | neovim | Remove `/opt/nvim` tree and symlinks |
| `gsettings-key` | GNOME terminal shortcuts | Reset keybinding or default terminal |
| `system-dropin` | avahi installer, etc. | Remove `/etc/...` drop-in we created |
| `skip` / `locale` / `hide-clone` | skipped paths, locale, clone rename | Left alone (by design) |

Not journaled (manual cleanup): LazyVim, `~/.cargo`/`~/.rustup` from Alacritty source builds, locale system config, user edits to skipped paths.
