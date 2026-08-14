#!/usr/bin/env bash
# Apt packages for LazyVim / Neovim plugins (not base machine bootstrap).
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install-lazyvim-deps.sh supports apt-based systems only." >&2
  exit 1
fi

PACKAGES=(
  build-essential
  python3-pip
  sqlite3
  trash-cli
  xdg-utils
)

echo "Updating package lists..."
sudo apt-get update

echo "Installing LazyVim apt packages..."
sudo apt-get install -y "${PACKAGES[@]}"

echo "Done."
