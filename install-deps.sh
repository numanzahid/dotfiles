#!/usr/bin/env bash
# Base apt packages for dotfiles (not user CLI tools).
# Neovim, bat, fd, fzf, lazygit, fastfetch, pfetch, etc. use scripts/ instead.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPT_DIR/scripts/lib/privilege.sh"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "install-deps.sh supports apt-based systems only." >&2
  exit 1
fi

df_ensure_sudo

PACKAGES=(
  bash
  ca-certificates
  curl
  git
  gzip
  jq
  less
  locales
  ripgrep
  sudo
  tar
  tmux
  wget
)

echo "Updating package lists..."
df_run_privileged apt-get update

echo "Installing packages..."
df_run_privileged apt-get install -y "${PACKAGES[@]}"

setup_utf8_locale() {
  if [[ ! -f /etc/locale.gen ]]; then
    return 0
  fi

  if grep -qE '^[[:space:]]*#?[[:space:]]*en_US\.UTF-8[[:space:]]+UTF-8' /etc/locale.gen; then
    df_run_privileged sed -i 's/^[[:space:]]*#\([[:space:]]*en_US\.UTF-8[[:space:]]\+UTF-8\)/\1/' /etc/locale.gen
  else
    echo "en_US.UTF-8 UTF-8" | df_run_privileged tee -a /etc/locale.gen >/dev/null
  fi

  df_run_privileged locale-gen en_US.UTF-8
  df_run_privileged update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
}

echo "Configuring UTF-8 locale..."
setup_utf8_locale

echo "Installing btop from upstream release..."
bash "$SCRIPT_DIR/scripts/btop-install-update.sh"

echo "Done. CLI tools (bat, fd, zoxide, eza): ./install-tools.sh"
echo "Lazygit:   ./scripts/lazygit-install-update.sh"
echo "Gh:        ./scripts/gh-install-update.sh"
echo "Fzf:       ./install.sh --fzf  (git install, recommended)"
echo "Fastfetch: ./scripts/fastfetch-install-update.sh"
echo "Pfetch:    ./scripts/pfetch-install-update.sh"
echo "Neovim:    ./install.sh --neovim  (or --all)"
echo "Nvm/Node:  ./scripts/nvm-install-update.sh"
echo "LazyVim:   ./lazyvim/install-lazyvim.sh  (optional, after neovim)"
