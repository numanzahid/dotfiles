# Lean LazyVim installer

Optional bootstrap for web, config, shell, Python, and Markdown editing.

Neovim itself is installed separately:

```bash
./install.sh --neovim           # Debian/Ubuntu, or --all
./install-fedora.sh --neovim    # Fedora, or --all
```

Then:

```bash
./lazyvim/install-lazyvim.sh
```

On root-only test hosts:

```bash
LAZYVIM_ALLOW_ROOT=true ./lazyvim/install-lazyvim.sh
```

## What it does

1. Validates Neovim (>= 0.11.2, LuaJIT); does not assume a previous LazyVim
2. Drops leftovers if they exist (Mason tree-sitter CLI, vim.pack, old extras lua, unused Debian clang/llvm)
3. Installs only missing packages (apt or dnf; no build-essential, no LLVM)
4. Installs prebuilt Tree-sitter CLI (no Rust/Cargo)
5. Ensures a working C compiler only if none exists (`gcc` + libc headers)
6. Links the LazyVim nvim config and enables the LazyVim profile
7. Runs headless `Lazy! sync` + `Lazy! load all`
8. Verifies health and prints disk usage

## Configuration

Edit `lazyvim/install.conf` for feature flags:

| Variable | Default | Purpose |
|----------|---------|---------|
| `ENABLE_DOCKER` | true | Docker/Compose LSP extra |
| `ENABLE_MARKDOWN_TOOLS` | false | Rich Markdown extra (extra Node tooling) |
| `ENABLE_VUE` / `SVELTE` / `ASTRO` / `ANGULAR` | false | Optional framework extras |
| `REQUIRE_NODE` | true | Install/use Node for web extras |
| `INSTALL_NVM_IF_MISSING` | true | Offer nvm when node/npm missing |
| `PROMPT_NVM_INSTALL` | true | Ask before running nvm installer from LazyVim |
| `LAZYVIM_ALLOW_ROOT` | false | Allow setup as root |
| `APT_CLEAN_AFTER_INSTALL` | true | apt clean for containers (Debian/Ubuntu only) |

## Scripts

| Script | Purpose |
|--------|---------|
| `install-lazyvim.sh` | Main installer |
| `install-system-deps.sh` | Missing commands via apt or dnf + gcc check |
| `install-nvm-node.sh` | LazyVim wrapper (calls `scripts/nvm-install-update.sh`) |
| `install-tree-sitter-cli.sh` | Prebuilt Tree-sitter CLI |
| `sync-lazyvim.sh` | Headless LazyVim sync |
| `cleanup-leftovers.sh` | Idempotent leftover cleanup (no-op on a fresh host) |
| `uninstall-lazyvim.sh` | Switch to plain nvim + remove nvim data |
| `measure-disk.sh` | Disk footprint report |

## System packages (only if the command is missing)

Same script on Debian/Ubuntu and Fedora. It checks commands first, then installs the matching package.

| Command | Debian/Ubuntu | Fedora | Why |
|---------|---------------|--------|-----|
| CA certs | `ca-certificates` | `ca-certificates` | HTTPS downloads |
| `curl` | `curl` | `curl` | LazyVim / Mason downloads |
| `git` | `git` | `git` | lazy.nvim, plugins |
| `unzip` | `unzip` | `unzip` | Tree-sitter CLI zip |
| `tar` | `tar` | `tar` | archives |
| `rg` | `ripgrep` | `ripgrep` | LazyVim search |
| `fd` | `fd-find` (`fdfind` symlink) | `fd-find` (binary is already `fd`) | file finding |
| `cc` / `gcc` | `gcc` + `libc6-dev` | `gcc` + `glibc-devel` | Tree-sitter parser builds |

Debian-only extras that Fedora does not get:

- `~/.local/bin/fd` -> `fdfind` (only when `fd` is missing and `fdfind` exists)
- `apt-get clean` when `APT_CLEAN_AFTER_INSTALL=true`
- older Tree-sitter CLI fallbacks (only if the current GitHub binary will not execute, typically old glibc)

Not installed: `build-essential`, `g++`, `clang`, `libclang-dev`, `llvm`, `python3-dev`, Rust.

## Tree-sitter CLI

Official prebuilt releases from GitHub, with SHA256 verification and an execution test.

Install order (first binary that actually runs wins):

| Try | Version | Asset |
|-----|---------|-------|
| 1 | 0.26.11 | `tree-sitter-cli-linux-x64.zip` |
| 2 | 0.25.6 | `tree-sitter-linux-x64.gz` |
| 3 | 0.24.7 | `tree-sitter-linux-x64.gz` |

On modern hosts (glibc >= 2.39), step 1 succeeds and matches nvim-treesitter's CLI minimum (0.26.1).

On Debian bookworm / Ubuntu 22.04, step 1 usually fails to execute; step 2 installs and **the install still completes**. The installer reports **WARN (degraded CLI)** because `:checkhealth nvim-treesitter` will ERROR. Highlighting, folds, and `:TSUpdate` still work.

`gcc` and libc headers stay installed when needed; they are not removed after parser builds.

## Leftovers

Every run of `./lazyvim/install-lazyvim.sh` calls `cleanup-leftovers.sh`. Missing paths and packages are a no-op, so a new machine and a re-run on an old box use the same command.

Removed only if present:

- `~/.local/share/nvim/site/pack/core` and `nvim-pack-lock.json`
- Mason `tree-sitter-cli` (this installer uses `~/.local/bin/tree-sitter`)
- `lua/plugins/nvim-extras.lua` (replaced by `dotfiles-extras.lua`)
- Debian apt packages this installer never needs: `libclang-dev`, `llvm-dev`, `clang`, `clangd`

Rust in `~/.cargo` is reported, not deleted.

## Uninstall

```bash
./lazyvim/uninstall-lazyvim.sh
```

This restores the plain editor config (`nvim-plain`) and removes LazyVim plugin data.
The Neovim binary is not removed.

## Disk usage

```bash
./lazyvim/measure-disk.sh
```

Typical LazyVim plugin + Mason footprint is hundreds of MB (not the old ~1.5GB Rust/LLVM path).

## Node.js / nvm

When `REQUIRE_NODE=true` and `node`/`npm` are missing, LazyVim asks to install Node via nvm, then runs:

```bash
./scripts/nvm-install-update.sh
```

Install or add Node majors anytime (interactive menu, latest patch in each line):

```bash
./scripts/nvm-install-update.sh
./scripts/nvm-install-update.sh 20
NODE_VERSION=22 ./scripts/nvm-install-update.sh
```

Menu defaults:
- `22` recommended (latest 22.x)
- `20` LTS (latest 20.x)
- `18` maintenance LTS (latest 18.x)

Skip LazyVim nvm prompt:

```bash
PROMPT_NVM_INSTALL=false LAZYVIM_ALLOW_ROOT=true ./lazyvim/install-lazyvim.sh
```

Skip Node entirely:

```bash
REQUIRE_NODE=false ./lazyvim/install-lazyvim.sh
```

## Staying in sync with upstream LazyVim

This repo does not vendor LazyVim as a second git clone. `home/.config/nvim` is the LazyVim starter plus our overlays (`lua/plugins/dotfiles-*.lua`, profile/treesitter helpers). Upstream LazyVim is a plugin (`LazyVim/LazyVim`) pinned in `home/.config/nvim/lazy-lock.json`.

### Plugin updates (usual path)

1. On one machine, update plugins (`:Lazy update` in nvim, or `./lazyvim/sync-lazyvim.sh`).
2. Commit `home/.config/nvim/lazy-lock.json` (and any lua you changed).
3. On other machines: `git pull`, then `./lazyvim/sync-lazyvim.sh`.

`sync-lazyvim.sh` is enough after a pull if Neovim, system deps, and Tree-sitter CLI are already in place.

### Full installer again

Re-run `./lazyvim/install-lazyvim.sh` on a machine when:

- first LazyVim setup on that host
- system deps, Tree-sitter CLI, or `install.conf` extras need to be applied
- you pulled starter/overlay lua that the installer links or rewrites

### Starter template updates (rare)

When [LazyVim/starter](https://github.com/LazyVim/starter) changes `init.lua` / `lua/config/lazy.lua`, merge those files by hand. Keep our overlays. Do not replace `lua/plugins/dotfiles-*.lua` or `lua/config/nvim-profile.lua`.
