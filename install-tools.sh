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
)

usage() {
  cat <<'EOF'
Usage: ./install-tools.sh [options]

Install or upgrade from upstream releases:
  bat, fd, zoxide, eza

Fastfetch is separate:
  ./install-fetch.sh

Lazygit is separate:
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

failed=()
for tool_script in "${TOOLS[@]}"; do
  echo
  echo "==> ${tool_script}"
  if bash "$SCRIPTS_DIR/$tool_script"; then
    continue
  fi
  echo "WARN: ${tool_script} failed (often GitHub); continuing" >&2
  failed+=("$tool_script")
done

echo
if ((${#failed[@]} > 0)); then
  echo "WARN: GitHub tool installs failed: ${failed[*]}" >&2
  echo "Re-run: ./install-tools.sh"
  exit 1
fi
echo "CLI tools install complete."
