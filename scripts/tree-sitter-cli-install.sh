#!/usr/bin/env bash
# Install tree-sitter CLI linked against local glibc (build from source when needed).
set -euo pipefail

TREE_SITTER_VERSION="${TREE_SITTER_VERSION:-0.26.8}"
INSTALL_DIR="${HOME}/.local/bin"
MASON_BIN="${HOME}/.local/share/nvim/mason/bin"
MASON_TS="${MASON_BIN}/tree-sitter"
MASON_PKG="${HOME}/.local/share/nvim/mason/packages/tree-sitter-cli"

tree_sitter_works() {
  local bin="$1"
  [[ -n "$bin" && -x "$bin" ]] && "$bin" --version &>/dev/null
}

find_working_tree_sitter() {
  local candidate
  for candidate in \
    "${INSTALL_DIR}/tree-sitter" \
    "$(command -v tree-sitter 2>/dev/null || true)" \
    "${MASON_TS}"; do
    if tree_sitter_works "$candidate"; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

remove_broken_mason_tree_sitter() {
  if [[ -e "${MASON_TS}" ]] && ! tree_sitter_works "${MASON_TS}"; then
    echo "Removing broken Mason tree-sitter-cli (prebuilt needs newer glibc)..."
    rm -f "${MASON_TS}"
    rm -rf "${MASON_PKG}"
  fi
}

ensure_rust() {
  if command -v cargo >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is required to install Rust via rustup." >&2
    exit 1
  fi

  echo "Installing Rust toolchain via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  # shellcheck disable=SC1091
  source "${HOME}/.cargo/env"
}

install_from_source() {
  ensure_rust

  if ! command -v cc >/dev/null 2>&1; then
    echo "ERROR: C compiler (cc/gcc) not found. Run ./install-deps.sh first." >&2
    exit 1
  fi

  mkdir -p "${INSTALL_DIR}"

  echo "Building tree-sitter-cli v${TREE_SITTER_VERSION} from source..."
  cargo install tree-sitter-cli --version "${TREE_SITTER_VERSION}" --locked --root "${HOME}/.local"

  if ! tree_sitter_works "${INSTALL_DIR}/tree-sitter"; then
    echo "ERROR: tree-sitter build finished but binary does not run." >&2
    exit 1
  fi
}

main() {
  local working

  if working="$(find_working_tree_sitter)"; then
    echo "tree-sitter OK: $("$working" --version) ($working)"
    exit 0
  fi

  remove_broken_mason_tree_sitter
  rm -f "${INSTALL_DIR}/tree-sitter"

  install_from_source

  working="$(find_working_tree_sitter)"
  echo "Installed tree-sitter: $("$working" --version) ($working)"
}

main "$@"
