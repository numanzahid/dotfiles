# dotfiles

Bash, tmux, nvim, and CLI tools. One `main` branch. Clone to `~/.dotfiles`, run the installer for your OS, then use `dotfiles` day to day.

The clone lives at `~/.dotfiles` (hidden). If you clone to `~/dotfiles`, the installer renames it on first run and continues from there.

Requires GNU coreutils/sed/date (Fedora and Debian/Ubuntu both ship these by default); not tested on musl (Alpine) or BSD userlands.

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

Each script does a **full install** by default: configs, packages, CLI tools, tmux TPM, and AI agent rules (devbox/desktop). No `--all` flag.

**devbox/desktop** includes: bat, fd, zoxide, eza, lazygit, gh, neovim, btop, gdu, fzf, tldr, TPM. **desktop** also installs nerd fonts by default (headless/VM use is the common case for devbox, so it doesn't); run `./scripts/cascadia-nerd-font-install-update.sh` by hand on a devbox that wants them too.

**server** is slimmer: copied configs (including `.gitconfig` and `btop`), base OS packages (apt or dnf), neovim, btop, gdu (no fzf, zoxide, lazygit, gh, tldr, TPM, fonts).

Installer options (all profiles):

```bash
./devbox.sh --configs-only    # link/copy configs only
./devbox.sh --software-only   # software only
./devbox.sh --dry-run         # preview
```

The installer also seeds `~/.ssh/config` and `~/.ssh/authorized_keys` from `home/.ssh/*.example` the first time (only if they don't already exist) — edit those real files afterward with your actual hosts/keys; the `.example` templates stay generic and tracked.

Single-tool upgrades: `./scripts/<tool>-install-update.sh`

## dotfiles command

Registered on PATH as `dotfiles` after the first install.

```bash
dotfiles update                 # pull repo, refresh configs, update stale software
dotfiles update --config-only   # pull repo and refresh configs only
dotfiles update --force         # discard repo changes, pull, full reinstall
dotfiles status                 # profile, nvim, fetch, versions, last updated, AI config
dotfiles install lazyvim        # optional LazyVim profile
dotfiles install lazyvim-lite   # optional LazyVim lite
dotfiles sync lazyvim           # apply lazy-lock.json after pull
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
dotfiles sync lazyvim
dotfiles sync lazyvim-lite
dotfiles install ai-sudo          # agent sudo through a tmux popup or desktop dialog (opt-in)
dotfiles install ai-config --nosandbox   # agent sandboxes + approvals off (opt-in)
dotfiles install ai-config        # servers only; devbox/desktop get it from update
./scripts/nvm-install-update.sh
./scripts/alacritty-install-update.sh
./scripts/kitty-install-update.sh
```

### Claude Code and Codex config

`devbox.sh`, `desktop.sh` and `dotfiles update` install the AI rules and **merge** a few keys
into `~/.claude/settings.json` and `~/.codex/config.toml` (both tools rewrite their config, so
nothing is symlinked whole). Servers: `dotfiles install ai-config` (copies instead of links).

| Source (`home/.config/dotfiles/ai-config/`) | Target | How |
|---|---|---|
| `claude/settings.base.json` | `~/.claude/settings.json` | `jq` merge; repo keys win |
| `codex/config.base.toml` | `~/.codex/config.toml` | per-key edit, validated with `tomllib` |
| `home/.claude/`, `home/.codex/` skills, agents, commands, prompts | `~/.claude/`, `~/.codex/` | symlink per item (copy on server) |

Add a key to a base file and re-run to roll it out. Auth, history and project trust are never
touched; a pre-merge backup is kept in `~/.local/share/dotfiles/backups/ai-config/`.

**Sandboxes and approvals** are opt-in: `dotfiles install ai-config --nosandbox` turns them off
for both tools (remembered, `update` keeps it); `--sandbox` puts them back.

**Agent sudo:** `dotfiles install ai-sudo` lets agents run `sudo` with a password prompt you
answer: a tmux popup when the agent runs in tmux, otherwise a desktop dialog (`zenity`,
`kdialog` or `yad`; Fedora: `dnf install zenity`). Opt-in per machine, never touches sandbox
settings. Remove with `dotfiles uninstall ai-sudo`.

Rules for working on this repo itself live in `.cursor/rules/*.mdc` (masters) and
`.claude/rules/*.md` (generated, committed). After editing an `.mdc`, run
`./scripts/ai-repo-rules-sync.sh`; CI runs it with `--check`.

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
| `link` / `copy` | devbox, server, fetch, AI rules, terminals | Restore from `*.pre-dotfiles` (or `~/.local/share/dotfiles/backups/` when dest is inside the clone) or remove our file |
| `binary` | GitHub release scripts, kitty, alacritty | Remove binary or install tree |
| `git-clone` | fzf, tpm | Remove clone directory |
| `package-new` | install-deps (only packages that were missing) | `apt`/`dnf` remove |
| `symlink` / `opt-tree` | neovim | Remove `/opt/nvim` tree and symlinks |
| `gsettings-key` | GNOME terminal shortcuts | Reset keybinding or default terminal |
| `system-dropin` | avahi installer, etc. | Remove `/etc/...` drop-in we created |
| `patch` | AI config key merges | Keys removed again by `df_strip_ai_rules` (not by the journal walk) |
| `skip` / `locale` / `hide-clone` | skipped paths, locale, clone rename | Left alone (by design) |

Not journaled (manual cleanup): LazyVim, `~/.cargo`/`~/.rustup` from Alacritty source builds, locale system config, user edits to skipped paths.
