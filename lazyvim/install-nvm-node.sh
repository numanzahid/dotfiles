#!/usr/bin/env bash
# LazyVim wrapper: run scripts/nvm-install-update.sh when Node is required.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

usage() {
  cat <<'EOF'
Usage: ./lazyvim/install-nvm-node.sh [options]

LazyVim wrapper: run ./scripts/nvm-install-update.sh when Node is required
(REQUIRE_NODE in lazyvim/install.conf). Skips if REQUIRE_NODE is false.

Options:
  --dry-run    Print the nvm installer command
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

main() {
  load_install_conf

  if ! truthy "$REQUIRE_NODE"; then
    log "skipping nvm/node install (REQUIRE_NODE=false)"
    return 0
  fi

  if ! truthy "${INSTALL_NVM_IF_MISSING:-true}"; then
    command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 ||
      die "node/npm missing and INSTALL_NVM_IF_MISSING=false"
    return 0
  fi

  local nvm_args=()
  [[ "$DRY_RUN" -eq 1 ]] && nvm_args+=(--dry-run)
  [[ ! -t 0 ]] && nvm_args+=(--non-interactive)

  if [[ -n "${NODE_VERSION:-}" ]]; then
    run env NODE_VERSION="$NODE_VERSION" bash "$DOTFILES_DIR/scripts/nvm-install-update.sh" "${nvm_args[@]}"
  else
    run bash "$DOTFILES_DIR/scripts/nvm-install-update.sh" "${nvm_args[@]}"
  fi

  load_nvm_into_shell || true
}

main "$@"
