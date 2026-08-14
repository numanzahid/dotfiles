#!/usr/bin/env bash
# Base apt packages for dotfiles (not user CLI tools).
# Neovim, bat, fd, fzf, lazygit, fastfetch, pfetch, etc. use scripts/ instead.
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install-deps.sh supports apt-based systems only." >&2
  exit 1
fi

PACKAGES=(
  bash
  btop
  ca-certificates
  curl
  git
  gzip
  jq
  less
  ripgrep
  sudo
  tar
  tmux
  wget
)

echo "Updating package lists..."
sudo apt-get update

echo "Installing packages..."
sudo apt-get install -y "${PACKAGES[@]}"

echo "Done. CLI tools (bat, fd, zoxide, eza): ./install-tools.sh"
echo "Lazygit:   ./scripts/lazygit-install-update.sh"
echo "Gh:        ./scripts/gh-install-update.sh"
echo "Fzf:       ./install.sh --fzf  (git install, recommended)"
echo "Fastfetch: ./scripts/fastfetch-install-update.sh"
echo "Pfetch:    ./scripts/pfetch-install-update.sh"
echo "Neovim:    ./install.sh --neovim  (or --all)"
echo "LazyVim:   ./install-lazyvim.sh  (optional, after neovim)"
