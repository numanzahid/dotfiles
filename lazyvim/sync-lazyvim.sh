#!/usr/bin/env bash
# Headless LazyVim / lazy.nvim synchronization.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./lazyvim/sync-lazyvim.sh [options]

Headless Lazy! sync and nvim-treesitter preload. Used by
./lazyvim/install-lazyvim.sh. Log: ~/.local/state/dotfiles/lazyvim-sync.log

Options:
  --dry-run    Print nvim commands without running them
  -h, --help   Show this help
EOF
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
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
fi

SYNC_LOG="${LAZYVIM_SYNC_LOG:-${HOME}/.local/state/dotfiles/lazyvim-sync.log}"

sync_lazyvim_plugins() {
  mkdir -p "$(dirname "$SYNC_LOG")"

  log "syncing LazyVim plugins (first run may take several minutes)..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run nvim --headless "+Lazy! sync" "+Lazy! load all" +qa
    return 0
  fi

  if ! nvim --headless "+Lazy! sync" "+Lazy! load all" +qa >"$SYNC_LOG" 2>&1; then
    tail -n 40 "$SYNC_LOG" >&2 || true
    die "Lazy! sync failed (see $SYNC_LOG)"
  fi

  log "Lazy! sync finished"
}

sync_treesitter_parsers() {
  log "ensuring Tree-sitter parsers (via nvim-treesitter)..."
  if [[ "$DRY_RUN" -eq 1 ]]; then
    run nvim --headless "+lua require('lazyvim.util').on_load('nvim-treesitter')" +qa
    return 0
  fi

  if nvim --headless "+lua require('lazyvim.util').on_load('nvim-treesitter')" +qa >>"$SYNC_LOG" 2>&1; then
    log "nvim-treesitter loaded"
    return 0
  fi

  warn "could not preload nvim-treesitter headlessly; parsers may finish on first interactive nvim start"
}

main() {
  command -v nvim >/dev/null 2>&1 || die "nvim not found"

  sync_lazyvim_plugins
  sync_treesitter_parsers
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
