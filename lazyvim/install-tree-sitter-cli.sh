#!/usr/bin/env bash
# Install official prebuilt Tree-sitter CLI (no Rust/Cargo).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/arch.sh
source "$SCRIPT_DIR/lib/arch.sh"

TREE_SITTER_VERSION="${TREE_SITTER_VERSION:-0.26.11}"
TREE_SITTER_REPO="tree-sitter/tree-sitter"
INSTALL_BIN="${HOME}/.local/bin/tree-sitter"

declare -A TREE_SITTER_SHA256=(
  [linux-x64]="ff1b7f9863f2faafd78dc0e66d902ee85b37f709b314b22c009f51caf233eebd"
  [linux-arm64]="db28509fe6db8902f9d14c43c486858c7486b42c3a96b30e811e73f105762336"
)

tree_sitter_works() {
  local bin="$1"
  [[ -n "$bin" && -x "$bin" ]] && "$bin" --version &>/dev/null
}

installed_tree_sitter_version() {
  local bin="$1"
  if ! tree_sitter_works "$bin"; then
    return 1
  fi
  "$bin" --version 2>/dev/null | awk '{print $NF}'
}

install_tree_sitter_binary() {
  local asset="tree-sitter-cli-${LAZYVIM_ARCH_LABEL}.zip"
  local url="https://github.com/${TREE_SITTER_REPO}/releases/download/v${TREE_SITTER_VERSION}/${asset}"
  local expected="${TREE_SITTER_SHA256[$LAZYVIM_ARCH_LABEL]:-}"
  local tmpdir archive extract_dir binary actual

  [[ -n "$expected" ]] || die "no SHA256 pin for ${LAZYVIM_ARCH_LABEL} (update lazyvim/install-tree-sitter-cli.sh)"

  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/${asset}"
  extract_dir="${tmpdir}/extract"
  trap 'rm -rf "$tmpdir"' EXIT

  mkdir -p "${HOME}/.local/bin"
  mkdir -p "$extract_dir"

  log "downloading Tree-sitter CLI v${TREE_SITTER_VERSION} (${LAZYVIM_ARCH_LABEL})"
  run curl -fL --retry 3 --retry-delay 1 -o "$archive" "$url"

  actual="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "SHA256 mismatch for ${asset} (expected ${expected}, got ${actual})"
  fi

  run unzip -oq "$archive" -d "$extract_dir"
  binary="$(find "$extract_dir" -type f -name tree-sitter | head -n 1)"
  [[ -n "$binary" && -f "$binary" ]] || die "tree-sitter binary not found in ${asset}"

  run install -m 755 "$binary" "${INSTALL_BIN}.new"
  run mv -f "${INSTALL_BIN}.new" "$INSTALL_BIN"

  tree_sitter_works "$INSTALL_BIN" || die "installed tree-sitter binary does not run"
  log "tree-sitter installed: $("$INSTALL_BIN" --version) ($INSTALL_BIN)"
}

main() {
  detect_lazyvim_arch

  if tree_sitter_works "$INSTALL_BIN"; then
    local current
    current="$(installed_tree_sitter_version "$INSTALL_BIN" || true)"
    if [[ "$current" == "$TREE_SITTER_VERSION" || "$current" == "v${TREE_SITTER_VERSION}" ]]; then
      log "tree-sitter already installed: $("$INSTALL_BIN" --version) ($INSTALL_BIN)"
      return 0
    fi
    log "upgrading tree-sitter from ${current:-unknown} to v${TREE_SITTER_VERSION}"
  elif tree_sitter_works "$(command -v tree-sitter 2>/dev/null || true)"; then
    log "using existing tree-sitter on PATH: $(command -v tree-sitter)"
    return 0
  fi

  install_tree_sitter_binary
}

main "$@"
