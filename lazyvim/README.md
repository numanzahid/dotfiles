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
5. Enables LazyVim nvim profile and official LazyExtras
6. Runs headless `Lazy! sync` + `Lazy! load all`
7. Verifies health and prints disk usage

## Configuration

Edit `lazyvim/install.conf` for feature flags:

| Variable | Default | Purpose |
|----------|---------|---------|
| `ENABLE_DOCKER` | true | Docker/Compose LSP extra |
| `ENABLE_MARKDOWN_TOOLS` | false | Rich Markdown extra (extra Node tooling) |
| `ENABLE_VUE` / `SVELTE` / `ASTRO` / `ANGULAR` | false | Optional framework extras |
| `REQUIRE_NODE` | true | Fail if node/npm missing |
| `LAZYVIM_ALLOW_ROOT` | false | Allow setup as root |
| `APT_CLEAN_AFTER_INSTALL` | true | apt clean for containers |

## Scripts

| Script | Purpose |
|--------|---------|
| `install-lazyvim.sh` | Main installer |
| `install-system-deps.sh` | Minimal apt + gcc check |
| `install-tree-sitter-cli.sh` | Prebuilt Tree-sitter CLI |
| `sync-lazyvim.sh` | Headless LazyVim sync |
| `migrate-legacy.sh` | Remove old LLVM/Rust leftovers |
| `uninstall-lazyvim.sh` | Switch to minimal + remove nvim data |
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

Prebuilt official release, auto-selected by host glibc:

| Host glibc | Version | Asset |
|------------|---------|-------|
| >= 2.39 | 0.26.11 | `tree-sitter-cli-linux-x64.zip` |
| >= 2.34 (Debian bookworm) | 0.25.6 | `tree-sitter-linux-x64.gz` |
| >= 2.29 | 0.24.7 | `tree-sitter-linux-x64.gz` |

Debian bookworm (glibc 2.36) cannot run 0.26.x prebuilts (they require glibc 2.39).

## Migration from old installer

```bash
./lazyvim/install-lazyvim.sh --migrate
```

Removes broken Mason tree-sitter, optional `libclang-dev`/`clang` apt packages, reports Rust leftovers.

## Uninstall

```bash
./lazyvim/uninstall-lazyvim.sh
```

## Disk usage

```bash
./lazyvim/measure-disk.sh
```

Typical LazyVim plugin + Mason footprint is hundreds of MB (not the old ~1.5GB Rust/LLVM path).

## Node.js

Web extras expect Node/npm from your separate dev-runtime installer. To skip:

```bash
REQUIRE_NODE=false ./lazyvim/install-lazyvim.sh
```
