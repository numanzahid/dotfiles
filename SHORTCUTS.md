# Dotfiles shortcuts

Quick reference for shell aliases, fzf, tmux, and CLI commands installed by this repo.

**Profiles:** `devbox` and `desktop` get the full set (fzf, zoxide, eza, trash). `server` gets a slimmer shell file (no fzf, zoxide, or `del`). See [Server profile](#server-profile) at the bottom.

---

## dotfiles CLI

Available after install as `dotfiles` (`~/.local/bin/dotfiles`).

| Command | What it does |
|---------|----------------|
| `dotfiles update` | Pull repo, refresh configs, update software (skips components updated in last 30 days) |
| `dotfiles update --force` | Discard tracked repo changes, pull (does not force-reinstall software) |
| `dotfiles update --dry-run` | Show what would run |
| `dotfiles status` | Show install profile and last-updated time per component |
| `dotfiles install devbox [flags]` | Same flags as `./devbox.sh` |
| `dotfiles install desktop [flags]` | Same flags as `./desktop.sh` |
| `dotfiles install server [flags]` | Same flags as `./server.sh` |
| `dotfiles install lazyvim [flags]` | Same flags as `./lazyvim/install-lazyvim.sh` |
| `dotfiles install lazyvim-lite [flags]` | Same flags as `./lazyvim-lite/install-lazyvim-lite.sh` |
| `dotfiles --help` | Full usage |

To reinstall or upgrade software immediately (ignores the 30-day skip):

```bash
./devbox.sh --all      # Debian/Ubuntu
./desktop.sh --all     # Fedora
```

Other useful scripts (see `README.md` for full list):

| Command | What it does |
|---------|----------------|
| `./install-ai-rules.sh` | Refresh Cursor, Codex, and Claude rules |
| `./install-fetch.sh` | Install fastfetch + boxed banner config |
| `scripts/nvim-profile.sh status` | Show current nvim profile |
| `scripts/nvim-profile.sh none` | Switch to plain nvim |
| `scripts/nvim-profile.sh lazyvim` | Switch to full LazyVim |
| `scripts/nvim-profile.sh lazyvim-lite` | Switch to LazyVim lite |

---

## fzf key bindings

Installed by `devbox.sh --fzf` / `desktop.sh --fzf` via `fzf install --all`. Active in interactive bash when fzf is on PATH.

| Key | Action |
|-----|--------|
| `Ctrl+R` | Fuzzy search bash history |
| `Ctrl+T` | Fuzzy pick a file; insert path at cursor |
| `Alt+C` | Fuzzy cd into a directory |
| `**` + `Tab` | Fuzzy path completion |

### While a fuzzy list is open

| Key | Action |
|-----|--------|
| `Ctrl+J` / `Ctrl+K` or arrows | Move selection |
| `Enter` | Accept selection |
| `Esc` | Cancel |
| `Ctrl+/` | Toggle preview window |
| `Ctrl+U` | Clear query |
| `Tab` | Multi-select toggle (when `-m` is enabled) |
| `Shift+Tab` | Multi-select backward |
| `Ctrl+R` (in history search) | Toggle sort by recency vs score |

### dotfiles fzf tuning (devbox/desktop)

When `fd`, `bat`, and `eza` are installed, dotfiles sets:

| Setting | Effect |
|---------|--------|
| `FZF_DEFAULT_COMMAND` | `fd` for files (respects `.gitignore`, includes hidden) |
| `FZF_CTRL_T_COMMAND` | Same as above for `Ctrl+T` |
| `FZF_ALT_C_COMMAND` | `fd --type d` for `Alt+C` |
| `FZF_CTRL_T_OPTS` | `bat` preview on file pick |
| `FZF_ALT_C_OPTS` | `eza` listing preview on directory pick |
| `FZF_DEFAULT_OPTS` | 40% height, reverse layout, border, right preview pane |

---

## fzf commands (devbox/desktop)

Custom helpers in `home/.shell_aliases_interactive.sh`:

| Command | What it does |
|---------|----------------|
| `ff` | File browser with `bat` preview (uses `fd` when available) |
| `fcd` | Fuzzy pick a directory under cwd and `cd` into it |
| `fe` | Fuzzy pick a file and open in `$EDITOR` (default `nvim`) |
| `fkill` | Fuzzy pick process(es) to kill (default signal 9) |
| `fkill 15` | Same, but send SIGTERM instead |

### fzf tips that work well here

**Open a file found by content (needs `rg`):**

```bash
nvim $(rg -l 'searchterm' | fzf)
```

**Edit several files at once:**

```bash
# Add to a one-off command:
fd -e md | fzf -m | xargs nvim
```

**Git log picker (optional; lazygit covers most git UI):**

```bash
git log --oneline --color=always |
  fzf --ansi --preview 'git show --color=always {1}' |
  awk '{print $1}'
```

**Man page search (needs `man` installed):**

```bash
man -k . 2>/dev/null | awk -F' - ' '{print $1}' |
  fzf --preview 'man {} 2>/dev/null | bat --color=always' |
  xargs man
```

**Simpler docs with examples (not installed by default; package is often `tealdeer`):**

```bash
tldr --list | fzf | xargs tldr
```

**Paste multiple paths at the cursor:**

```bash
export FZF_CTRL_T_OPTS="$FZF_CTRL_T_OPTS --multi"
# Then Ctrl+T, Tab to select several files, Enter inserts all
```

**fcd vs Alt+C vs zoxide:**

| Tool | Best for |
|------|----------|
| `z foo` / `cd foo` | Jump to a dir you have visited before (zoxide) |
| `Alt+C` | Explore and cd under the current directory |
| `fcd` | Same idea as `Alt+C`, but as an explicit command |

---

## Navigation and cd (devbox/desktop)

`cd` is overridden to use zoxide when installed.

| Command | What it does |
|---------|----------------|
| `cd dir` | Normal cd if `dir` exists; otherwise `z dir` (fuzzy memory) |
| `cd` | Go home |
| `cd -` | Previous directory |
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `....` | `cd ../../..` |
| `-` | `cd -` (previous directory) |
| `mkcd dir` | `mkdir -p dir` and `cd dir` |

---

## Listing files

### devbox / desktop (with eza)

| Alias | What it does |
|-------|----------------|
| `ls` | Long list, human sizes, dirs first, git status, icons |
| `lsa` | Same, including hidden |
| `lt` | Tree view, depth 2 |
| `lta` | Tree view, depth 2, including hidden |

### server (GNU ls stand-in)

| Alias | What it does |
|-------|----------------|
| `ls` | Long list, human sizes, dirs first, color |
| `lsa` | Same, including hidden |
| `lt` | Two-level directory listing |
| `lta` | Two-level listing, including hidden |

---

## Files, trash, and grep

| Command | What it does |
|---------|----------------|
| `del path` | Move to trash via `trash-put` (devbox/desktop only) |
| `rm` | Still normal `rm` (not overridden) |
| `grep` / `fgrep` / `egrep` | Color always on |

---

## fastfetch banner

| Command | What it does |
|---------|----------------|
| `fetch` | Run boxed fastfetch banner (same art as tmux) |
| `fastfetch` | No args: boxed banner. With args: real fastfetch |

Login banner runs once per shell unless skipped (see [Environment toggles](#environment-toggles)).

Install fetch config: `./install-fetch.sh` or `./server.sh --fetch`.

---

## tmux

Default prefix: `Ctrl+b` (tmux default).

| Key / action | What it does |
|--------------|----------------|
| `prefix + Shift + I` | Install tmux plugins (TPM; run once after install) |
| `prefix + c` | New window (shows fastfetch banner, then shell) |
| `prefix + %` | Split pane horizontally |
| `prefix + "` | Split pane vertically |
| `prefix + x` | Kill pane (no confirmation) |
| Mouse wheel | Scroll tmux history (not shell history) |
| Copy mode `v` | Begin selection (vi keys) |
| Copy mode `y` | Copy selection |

Shell alias: `tmux` runs `tmux -u` (UTF-8).

SSH autostart: interactive SSH sessions attach to or create tmux automatically. Disable with `NO_TMUX=1` (see below).

---

## Kitty

| Command | What it does |
|---------|----------------|
| `sshk host` | `kitten ssh host` (only if Kitty `kitten` is installed) |

---

## Desktop

| Command | What it does |
|---------|----------------|
| `alert` | Desktop notification for the previous command (needs `notify-send`) |

Append `; alert` or `&& alert` to long commands to get notified when they finish.

---

## Environment toggles

Set on the `ssh`/`bash` command line or export in the session.

| Variable | Effect |
|----------|--------|
| `NO_TMUX=1` | Skip tmux autostart on SSH (`NO_TMUX=1 ssh host`) |
| `NO_FETCH=1` | Skip login fastfetch banner |
| `EDITOR` | Default editor for `fe` and git (default: `nvim`) |

---

## Neovim profiles

| Command | What it does |
|---------|----------------|
| `scripts/nvim-profile.sh status` | Show active profile |
| `scripts/nvim-profile.sh none` | Plain nvim config |
| `scripts/nvim-profile.sh lazyvim` | Full LazyVim |
| `scripts/nvim-profile.sh lazyvim-lite` | LazyVim without Mason/LSP/Node |

Install profiles: `dotfiles install lazyvim` or `dotfiles install lazyvim-lite`.

---

## Server profile

`server.sh` copies a slimmer `~/.shell_aliases_interactive.sh`. Compared to devbox/desktop:

| Feature | server |
|---------|--------|
| fzf (`ff`, `fcd`, `fe`, `fkill`, key bindings) | No |
| zoxide (`cd` override) | No |
| `del` (trash-put) | No |
| eza | No (GNU `ls` aliases instead) |
| `sshk` | No |
| `fetch` / fastfetch wrapper | Yes (if fastfetch installed) |
| `..`, `mkcd`, `alert`, tmux alias | Yes |

Server hosts can still use `dotfiles` if the clone remains, or the copy under `~/.install-scripts/dotfiles-cli/` after `server.sh`.
