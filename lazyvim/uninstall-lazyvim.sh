#!/usr/bin/env bash
# Remove LazyVim runtime data and switch nvim back to plain (no profile file).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/nvim-profile.sh
source "$SCRIPT_DIR/lib/nvim-profile.sh"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Remove LazyVim runtime data (~/.local/share/nvim, cache, state) and
switch nvim back to the plain profile (no LazyVim). Does not uninstall
Neovim itself.

Options:
  --keep-tree-sitter   Keep ~/.local/bin/tree-sitter
  --dry-run            Print actions only
  -h, --help           Show this help
EOF
}

KEEP_TREE_SITTER=0

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keep-tree-sitter) KEEP_TREE_SITTER=1 ;;
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
}

confirm() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  read -r -p "Remove LazyVim data under ~/.local/share/nvim and ~/.cache/nvim? [y/N] " reply
  case "${reply:-N}" in
    y | Y | yes | YES) ;;
    *) die "aborted" ;;
  esac
}

main() {
  parse_args "$@"
  confirm

  log "switching nvim back to plain editor config"
  run clear_nvim_profile

  for path in \
    "${XDG_DATA_HOME:-$HOME/.local/share}/nvim" \
    "${XDG_CACHE_HOME:-$HOME/.cache}/nvim" \
    "${XDG_STATE_HOME:-$HOME/.local/state}/nvim"; do
    if [[ -e "$path" ]]; then
      log "removing $path"
      run rm -rf "$path"
    fi
  done

  if [[ "$KEEP_TREE_SITTER" -eq 0 && -x "${HOME}/.local/bin/tree-sitter" ]]; then
    log "removing ${HOME}/.local/bin/tree-sitter"
    run rm -f "${HOME}/.local/bin/tree-sitter"
  fi

  log "LazyVim uninstall complete (Neovim binary was not removed)"
}

main "$@"
