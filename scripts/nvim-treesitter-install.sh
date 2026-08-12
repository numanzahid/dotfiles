#!/usr/bin/env bash
# Install extra Tree-sitter parsers after Neovim and LazyVim are set up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v nvim >/dev/null 2>&1; then
  echo "ERROR: nvim not found. Run ./scripts/neovim-install-update.sh first." >&2
  exit 1
fi

echo "Ensuring tree-sitter CLI works on this glibc..."
bash "${SCRIPT_DIR}/tree-sitter-cli-install.sh"

echo "Syncing LazyVim plugins (first run may take a while)..."
nvim --headless "+Lazy! sync" +qa

echo "Installing Tree-sitter parsers: bash, regex"
nvim --headless "+TSUpdateSync bash regex" +qa

echo "Done."
