# Lean LazyVim installer

Optional bootstrap for web, config, shell, Python, and Markdown editing.

Neovim itself is installed separately:

```bash
./install.sh --neovim   # or --all
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

1. Validates Neovim (>= 0.11.2, LuaJIT)
2. Installs only missing apt packages (no build-essential, no LLVM)
3. Installs prebuilt Tree-sitter CLI (no Rust/Cargo)
4. Ensures minimal `gcc` + `libc6-dev` only if no working C compiler exists
5. Links the LazyVim nvim config and enables the LazyVim profile
6. Runs headless `Lazy! sync` + `Lazy! load all`
7. Verifies health and prints disk usage

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
| `APT_CLEAN_AFTER_INSTALL` | true | apt clean for containers |

## Scripts

| Script | Purpose |
|--------|---------|
| `install-lazyvim.sh` | Main installer |
| `install-system-deps.sh` | Minimal apt + gcc check |
| `install-nvm-node.sh` | LazyVim wrapper (calls `scripts/nvm-install-update.sh`) |
| `install-tree-sitter-cli.sh` | Prebuilt Tree-sitter CLI |
| `sync-lazyvim.sh` | Headless LazyVim sync |
| `migrate-legacy.sh` | Remove old LLVM/Rust leftovers |
| `uninstall-lazyvim.sh` | Switch to plain nvim + remove nvim data |
| `measure-disk.sh` | Disk footprint report |

## Apt packages (only if missing)

| Package | Why |
|---------|-----|
| `ca-certificates` | HTTPS downloads |
| `curl` | LazyVim / Mason downloads |
| `git` | lazy.nvim, plugins |
| `unzip` | Tree-sitter CLI zip |
| `tar` | archives |
| `ripgrep` | LazyVim search |
| `fd-find` | file finding (`fd` symlink in `~/.local/bin`) |
| `gcc` + `libc6-dev` | only if no working C compiler (Tree-sitter parsers) |

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

`gcc` + `libc6-dev` stay installed when needed; they are not removed after parser builds.

## Migration from old installer

```bash
./lazyvim/install-lazyvim.sh --migrate
```

Removes broken Mason tree-sitter, optional `libclang-dev`/`clang` apt packages, reports Rust leftovers.

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
