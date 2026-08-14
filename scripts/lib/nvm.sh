#!/usr/bin/env bash
# Shared nvm helpers for dotfiles install scripts.

nvm_dir() {
  printf '%s' "${NVM_DIR:-$HOME/.nvm}"
}

nvm_load() {
  export NVM_DIR="$(nvm_dir)"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    source "$NVM_DIR/nvm.sh"
    return 0
  fi
  return 1
}

nvm_node_ready() {
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1
}
