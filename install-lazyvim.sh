#!/usr/bin/env bash
# LazyVim runtime setup (apt extras, tree-sitter CLI, plugin sync).
# Neovim itself is installed by ./install.sh --neovim or --all.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

usage() {
  cat <<'EOF'
Usage: ./install-lazyvim.sh [options]

Install LazyVim extras (not part of ./install.sh --all):
  - apt packages for nvim plugins (build-essential, libclang-dev, pip, sqlite3, trash-cli, xdg-utils)
  - tree-sitter CLI (built from source on older glibc)
  - LazyVim plugin sync + tree-sitter parsers

Requires: nvim (run ./install.sh --neovim first)

Options:
  --dry-run    Print actions without changing anything
  -h, --help   Show this help
EOF
}

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

if ! command -v nvim >/dev/null 2>&1; then
  echo "ERROR: nvim not found. Run ./install.sh --neovim first." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "$SCRIPTS_DIR/nvim-profile.sh"
echo "[lazyvim] enabling LazyVim nvim profile..."
run set_nvim_profile "lazyvim"

echo "[lazyvim] installing apt dependencies..."
run bash "$SCRIPTS_DIR/install-lazyvim-deps.sh"

echo "[lazyvim] ensuring tree-sitter CLI..."
run bash "$SCRIPTS_DIR/tree-sitter-cli-install.sh"

echo "[lazyvim] syncing LazyVim and tree-sitter parsers..."
run bash "$SCRIPTS_DIR/nvim-treesitter-install.sh"

cat <<'EOF'

LazyVim setup complete.

Next: run nvim and wait for any remaining first-time setup.

EOF
