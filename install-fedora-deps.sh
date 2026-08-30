#!/usr/bin/env bash
# Base dnf packages for Fedora (official repos only, never COPR).
# CLI tools that may come from GitHub are chosen by ./install-fedora.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/privilege.sh
source "$SCRIPT_DIR/scripts/lib/privilege.sh"
# shellcheck source=scripts/lib/platform.sh
source "$SCRIPT_DIR/scripts/lib/platform.sh"

if [[ "$(df_host_os_id)" != "fedora" ]]; then
  echo "install-fedora-deps.sh is for Fedora. On Debian/Ubuntu use ./install-deps.sh" >&2
  exit 1
fi

if ! command -v dnf >/dev/null 2>&1; then
  echo "install-fedora-deps.sh needs dnf." >&2
  exit 1
fi

df_ensure_sudo

PACKAGES=(
  bash
  bash-completion
  ca-certificates
  curl
  git
  gzip
  jq
  less
  ripgrep
  tar
  tmux
  trash-cli
  wget
)

echo "Refreshing Fedora metadata..."
df_run_privileged dnf makecache

echo "Installing Fedora packages (official repos only)..."
df_run_privileged dnf install -y "${PACKAGES[@]}"

echo "Done. Tool binaries: ./install-fedora.sh --tools --neovim --btop --fzf --gh --lazygit --starship"
echo "dnf: bat fd-find eza btop fzf gh neovim. GitHub: zoxide lazygit starship."
echo "Fetch banners: ./install-fetch.sh"
echo "Nvm/Node:      ./scripts/nvm-install-update.sh"
echo "AI CLIs:       ./install-ai-cli.sh"
echo "LazyVim:       ./lazyvim/install-lazyvim.sh or ./lazyvim-lite/install-lazyvim-lite.sh"
