#!/usr/bin/env bash
# Remove leftovers this installer does not use.
# Idempotent: a fresh host is a no-op; re-runs only delete what is present.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./lazyvim/cleanup-leftovers.sh [options]

Remove leftovers this LazyVim installer does not use (vim pack path,
Mason tree-sitter, old extras lua). Idempotent: a fresh host is a no-op.

Does not uninstall LazyVim itself (see ./lazyvim/uninstall-lazyvim.sh).
Does not remove ~/.cargo or ~/.rustup (prints a hint if they exist).

Options:
  --dry-run    Print what would be removed
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

remove_user_path() {
  local path="$1"

  [[ -e "$path" || -L "$path" ]] || return 0

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would remove leftover: $path"
    return 0
  fi

  log "removing leftover: $path"
  if command -v trash-put >/dev/null 2>&1; then
    trash-put "$path"
  else
    rm -rf "$path"
  fi
}

cleanup_vim_pack() {
  remove_user_path "${HOME}/.local/share/nvim/site/pack/core"
  remove_user_path "${HOME}/.config/nvim/nvim-pack-lock.json"
}

cleanup_mason_tree_sitter() {
  # This installer owns ~/.local/bin/tree-sitter. Mason's copy is unused extra.
  remove_user_path "${HOME}/.local/share/nvim/mason/bin/tree-sitter"
  remove_user_path "${HOME}/.local/share/nvim/mason/packages/tree-sitter-cli"
}

cleanup_legacy_extras_lua() {
  remove_user_path "$NVIM_CONFIG_DIR/lua/plugins/nvim-extras.lua"
  remove_user_path "$NVIM_CONFIG_DIR/lua/plugins/dotfiles-extras.lua"
}

report_rust_leftovers() {
  if [[ -d "${HOME}/.cargo" ]]; then
    warn "Rust toolchain is present in ~/.cargo (not required for LazyVim; remove manually if unused):"
    warn "  rustup self uninstall"
    warn "  trash-put ~/.cargo ~/.rustup"
  fi
}

main() {
  load_install_conf
  log "checking for leftovers (no-op if none)"
  cleanup_vim_pack
  cleanup_mason_tree_sitter
  cleanup_legacy_extras_lua
  report_rust_leftovers
}

main "$@"
