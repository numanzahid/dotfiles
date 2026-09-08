#!/usr/bin/env bash
# Remove LazyVim / lazyvim-lite runtime data and switch back to plain nvim.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/nvim-profile.sh
source "$SCRIPT_DIR/lib/nvim-profile.sh"
# shellcheck source=../scripts/lib/component-state.sh
source "$DOTFILES_DIR/scripts/lib/component-state.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]
       dotfiles uninstall lazyvim [--dry-run] [--yes]

Remove LazyVim and lazyvim-lite plugin data, then switch nvim back to the
plain editor config (nvim-plain). Does not uninstall the Neovim binary.

Removes:
  ~/.local/share/nvim, ~/.cache/nvim, ~/.local/state/nvim
  ~/.local/bin/tree-sitter (unless --keep-tree-sitter)
  lazyvim / lazyvim-lite entries in component-state.tsv

Options:
  --keep-tree-sitter   Keep ~/.local/bin/tree-sitter
  --yes, -y            Skip confirmation
  --dry-run            Print actions only
  -h, --help           Show this help
EOF
}

KEEP_TREE_SITTER=0
ASSUME_YES=0

remove_user_path() {
  local path="$1"

  [[ -e "$path" || -L "$path" ]] || return 0

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would remove $path"
    return 0
  fi

  log "removing $path"
  if command -v trash-put >/dev/null 2>&1; then
    trash-put "$path"
  else
    rm -rf "$path"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keep-tree-sitter) KEEP_TREE_SITTER=1 ;;
      --yes | -y) ASSUME_YES=1 ;;
      --dry-run) DRY_RUN=1 ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done

  if [[ "${DF_YES:-0}" -eq 1 || "${DOTFILES_YES:-0}" -eq 1 ]]; then
    ASSUME_YES=1
  fi
}

confirm() {
  if [[ "$DRY_RUN" -eq 1 || "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  read -r -p "Remove LazyVim / lazyvim-lite and switch back to plain nvim? [y/N] " reply
  case "${reply:-N}" in
    y | Y | yes | YES) ;;
    *) die "aborted" ;;
  esac
}

forget_lazyvim_component_state() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would forget component state: lazyvim lazyvim-lite"
    return 0
  fi
  df_component_forget lazyvim
  df_component_forget lazyvim-lite
}

main() {
  parse_args "$@"
  confirm

  log "switching nvim back to plain editor config (nvim-plain)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "would run clear_nvim_profile"
  else
    clear_nvim_profile
  fi

  for path in \
    "${XDG_DATA_HOME:-$HOME/.local/share}/nvim" \
    "${XDG_CACHE_HOME:-$HOME/.cache}/nvim" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/nvim" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/lazyvim-sync.log" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/lazyvim-lite-sync.log"; do
    remove_user_path "$path"
  done

  if [[ "$KEEP_TREE_SITTER" -eq 0 ]]; then
    remove_user_path "${HOME}/.local/bin/tree-sitter"
  fi

  forget_lazyvim_component_state

  log "LazyVim uninstall complete (plain nvim config active; Neovim binary kept)"
  log "Reinstall later: dotfiles install lazyvim | dotfiles install lazyvim-lite"
}

main "$@"
