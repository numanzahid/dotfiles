#!/usr/bin/env bash
# Remove leftovers this installer does not use.
# Idempotent: a fresh host is a no-op; re-runs only delete what is present.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/lib/privilege.sh
source "$DOTFILES_DIR/scripts/lib/privilege.sh"

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

# Old installer pulled LLVM/clang for Tree-sitter. This one never installs them.
cleanup_unneeded_compiler_packages() {
  local pkg removed=0

  if ! command -v dpkg-query >/dev/null 2>&1; then
    return 0
  fi

  for pkg in libclang-dev llvm-dev clang clangd; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        log "would apt remove leftover $pkg"
      else
        log "removing leftover apt package: $pkg"
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
  cleanup_unneeded_compiler_packages
  report_rust_leftovers
}

main "$@"
