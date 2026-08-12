#!/usr/bin/env bash
# Install or upgrade CLI tools from upstream releases (not apt).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/scripts"

TOOLS=(
  bat-install-update.sh
  fd-install-update.sh
  zoxide-install-update.sh
  eza-install-update.sh
  chafa-install-update.sh
)

usage() {
  cat <<'EOF'
Usage: ./install-tools.sh [options]

Install or upgrade from upstream releases:
  bat, fd, zoxide, eza, chafa

Fastfetch and lazygit are separate:
  ./scripts/fastfetch-install-update.sh
  ./scripts/lazygit-install-update.sh

Options:
  -h, --help   Show this help

Re-run anytime to upgrade:
  ./install-tools.sh
  ./install.sh --tools
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

for tool_script in "${TOOLS[@]}"; do
  echo
  echo "==> ${tool_script}"
  bash "$SCRIPTS_DIR/$tool_script"
done

echo
echo "CLI tools install complete."
