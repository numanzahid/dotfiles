#!/usr/bin/env bash
# Cleanup after the old heavyweight LazyVim installer (Rust/Cargo/LLVM).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/lib/privilege.sh
source "$DOTFILES_DIR/scripts/lib/privilege.sh"

remove_minimal_vim_pack() {
  local pack_dir="${HOME}/.local/share/nvim/site/pack/core"
  local lockfile="${HOME}/.config/nvim/nvim-pack-lock.json"

  if [[ -d "$pack_dir" ]]; then
    log "removing minimal-profile vim.pack directory: $pack_dir"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would rm -rf $pack_dir"
    else
      rm -rf "$pack_dir"
    fi
  fi

  if [[ -f "$lockfile" ]]; then
    log "removing stale vim.pack lockfile: $lockfile"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "would rm -f $lockfile"
    else
      rm -f "$lockfile"
    fi
  fi
}

remove_broken_mason_tree_sitter() {
  local mason_ts="${HOME}/.local/share/nvim/mason/bin/tree-sitter"
  local mason_pkg="${HOME}/.local/share/nvim/mason/packages/tree-sitter-cli"

  if [[ -e "$mason_ts" ]] && ! "$mason_ts" --version &>/dev/null 2>&1; then
    log "removing broken Mason tree-sitter-cli"
    rm -f "$mason_ts"
    rm -rf "$mason_pkg"
  fi
}

optional_remove_heavy_apt_packages() {
  local pkg removed=0

  for pkg in libclang-dev llvm-dev clang clangd; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log "would apt remove $pkg"
      else
        df_run_privileged apt-get remove -y "$pkg" || true
      fi
      removed=1
    fi
  done

  if [[ "$removed" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
    df_run_privileged apt-get autoremove -y || true
  fi
}

report_rust_leftovers() {
  if [[ -d "${HOME}/.cargo" ]]; then
    warn "Rust toolchain may still be present in ~/.cargo (safe to remove manually if unused):"
    warn "  rustup self uninstall"
    warn "  rm -rf ~/.cargo ~/.rustup"
  fi
}

main() {
  case "${1:-}" in
    --pack-only)
      remove_minimal_vim_pack
      exit 0
      ;;
  esac

  log "migrating from legacy LazyVim installer"
  remove_minimal_vim_pack
  remove_broken_mason_tree_sitter
  optional_remove_heavy_apt_packages
  report_rust_leftovers
  log "migration pass complete"
}

main "$@"
