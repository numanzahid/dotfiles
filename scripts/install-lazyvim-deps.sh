#!/usr/bin/env bash
# Apt packages for LazyVim / Neovim plugins (not base machine bootstrap).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=scripts/lib/privilege.sh
source "$DOTFILES_DIR/scripts/lib/privilege.sh"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install-lazyvim-deps.sh supports apt-based systems only." >&2
  exit 1
fi

df_ensure_sudo

PACKAGES=(
  build-essential
  python3-pip
  sqlite3
  trash-cli
  xdg-utils
)

echo "Updating package lists..."
df_run_privileged apt-get update

echo "Installing LazyVim apt packages..."
df_run_privileged apt-get install -y "${PACKAGES[@]}"

echo "Done."
