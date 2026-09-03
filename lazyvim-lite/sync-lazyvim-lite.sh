#!/usr/bin/env bash
# Headless LazyVim-lite / lazy.nvim synchronization.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LAZYVIM_SYNC_LOG="${HOME}/.local/state/dotfiles/lazyvim-lite-sync.log"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./lazyvim-lite/sync-lazyvim-lite.sh [options]

Headless Lazy! sync for LazyVim-lite. Log:
~/.local/state/dotfiles/lazyvim-lite-sync.log

Options:
  --dry-run    Print nvim commands without running them
  -h, --help   Show this help
EOF
}

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
# shellcheck source=../lazyvim/sync-lazyvim.sh
source "$SCRIPT_DIR/../lazyvim/sync-lazyvim.sh"

main "$@"
