#!/usr/bin/env bash
# Headless LazyVim-lite / lazy.nvim synchronization.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LAZYVIM_SYNC_LOG="${HOME}/.local/state/dotfiles/lazyvim-lite-sync.log"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=../lazyvim/sync-lazyvim.sh
source "$SCRIPT_DIR/../lazyvim/sync-lazyvim.sh"

main "$@"
