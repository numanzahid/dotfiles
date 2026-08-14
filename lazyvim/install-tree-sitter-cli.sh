#!/usr/bin/env bash
# Install official prebuilt Tree-sitter CLI (no Rust/Cargo).
# Picks a release compatible with the host glibc (Debian bookworm = 2.36).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/arch.sh
source "$SCRIPT_DIR/lib/arch.sh"

TREE_SITTER_REPO="tree-sitter/tree-sitter"
INSTALL_BIN="${HOME}/.local/bin/tree-sitter"

# glibc >= 2.39
TREE_SITTER_VERSION_NEW="${TREE_SITTER_VERSION_NEW:-0.26.11}"
# glibc >= 2.34 (Debian bookworm / Ubuntu 22.04)
TREE_SITTER_VERSION_BOOKWORM="${TREE_SITTER_VERSION_BOOKWORM:-0.25.6}"
# glibc >= 2.29
TREE_SITTER_VERSION_LEGACY="${TREE_SITTER_VERSION_LEGACY:-0.24.7}"

declare -A TREE_SITTER_SHA256_ZIP=(
  ["0.26.11:linux-x64"]="ff1b7f9863f2faafd78dc0e66d902ee85b37f709b314b22c009f51caf233eebd"
  ["0.26.11:linux-arm64"]="db28509fe6db8902f9d14c43c486858c7486b42c3a96b30e811e73f105762336"
)

declare -A TREE_SITTER_SHA256_GZ=(
  ["0.25.6:linux-x64"]="c300ea9f2ca368186ce1308793aaad650c3f6db78225257cbb5be961aeff4038"
  ["0.25.6:linux-arm64"]="daf6f8e5b2f87195370f28dd9936a168920831fc2a5e0987e0bedd9999b6e2b8"
  ["0.24.7:linux-x64"]="628fa0e1c4d78b5d4f7de64b6ab42fc050e3bee14cb92a076beb82d762d76d69"
  ["0.24.7:linux-arm64"]="bad9cd53adcbd18df33084bb811b8cf7868fffd79437acfc83ac1025e7574c78"
)

host_glibc_version() {
  local ver
  ver="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
  [[ -n "$ver" ]] || ver="$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
  [[ -n "$ver" ]] || die "could not detect glibc version"
  printf '%s' "$ver"
}

select_tree_sitter_release() {
  local glibc="$1"

  if version_ge "$glibc" "2.39"; then
    TREE_SITTER_SELECTED_VERSION="$TREE_SITTER_VERSION_NEW"
    TREE_SITTER_SELECTED_FORMAT="zip"
    return 0
  fi

  if version_ge "$glibc" "2.34"; then
    TREE_SITTER_SELECTED_VERSION="$TREE_SITTER_VERSION_BOOKWORM"
    TREE_SITTER_SELECTED_FORMAT="gz"
    warn "glibc ${glibc} < 2.39: using tree-sitter v${TREE_SITTER_SELECTED_VERSION} (bookworm-compatible prebuilt)"
    return 0
  fi

  if version_ge "$glibc" "2.29"; then
    TREE_SITTER_SELECTED_VERSION="$TREE_SITTER_VERSION_LEGACY"
    TREE_SITTER_SELECTED_FORMAT="gz"
    warn "glibc ${glibc} is old: using tree-sitter v${TREE_SITTER_SELECTED_VERSION}"
    return 0
  fi

  die "glibc ${glibc} is too old for official tree-sitter CLI prebuilts (need >= 2.29)"
}

version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -C -V
}

tree_sitter_works() {
  local bin="$1"
  [[ -n "$bin" && -x "$bin" ]] && "$bin" --version &>/dev/null
}

tree_sitter_error() {
  local bin="$1"
  local err
  err="$("$bin" --version 2>&1 >/dev/null || true)"
  printf '%s' "${err:-unknown error}"
}

installed_tree_sitter_version() {
  local bin="$1"
  if ! tree_sitter_works "$bin"; then
    return 1
  fi
  "$bin" --version 2>/dev/null | awk '{print $NF}'
}

release_asset_name() {
  case "$TREE_SITTER_SELECTED_FORMAT" in
    zip) printf 'tree-sitter-cli-%s.zip' "$LAZYVIM_ARCH_LABEL" ;;
    gz) printf 'tree-sitter-linux-%s.gz' "$LAZYVIM_ARCH_LABEL" ;;
    *) die "unknown tree-sitter archive format: $TREE_SITTER_SELECTED_FORMAT" ;;
  esac
}

expected_sha256() {
  local key="${TREE_SITTER_SELECTED_VERSION}:${LAZYVIM_ARCH_LABEL}"
  case "$TREE_SITTER_SELECTED_FORMAT" in
    zip) printf '%s' "${TREE_SITTER_SHA256_ZIP[$key]:-}" ;;
    gz) printf '%s' "${TREE_SITTER_SHA256_GZ[$key]:-}" ;;
  esac
}

install_tree_sitter_binary() {
  local glibc asset url expected tmpdir archive extract_dir binary actual err

  glibc="$(host_glibc_version)"
  select_tree_sitter_release "$glibc"

  asset="$(release_asset_name)"
  url="https://github.com/${TREE_SITTER_REPO}/releases/download/v${TREE_SITTER_SELECTED_VERSION}/${asset}"
  expected="$(expected_sha256)"
  [[ -n "$expected" ]] || die "no SHA256 pin for ${TREE_SITTER_SELECTED_VERSION} ${LAZYVIM_ARCH_LABEL} (update install-tree-sitter-cli.sh)"

  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/${asset}"
  extract_dir="${tmpdir}/extract"
  trap 'rm -rf "$tmpdir"' EXIT

  mkdir -p "${HOME}/.local/bin"
  mkdir -p "$extract_dir"

  log "downloading Tree-sitter CLI v${TREE_SITTER_SELECTED_VERSION} (${LAZYVIM_ARCH_LABEL}, glibc ${glibc})"
  run curl -fL --retry 3 --retry-delay 1 -o "$archive" "$url"

  actual="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "SHA256 mismatch for ${asset} (expected ${expected}, got ${actual})"
  fi

  case "$TREE_SITTER_SELECTED_FORMAT" in
    zip)
      run unzip -oq "$archive" -d "$extract_dir"
      binary="$(find "$extract_dir" -type f -name tree-sitter | head -n 1)"
      ;;
    gz)
      binary="${extract_dir}/tree-sitter"
      run gunzip -c "$archive" >"${binary}.new"
      run mv -f "${binary}.new" "$binary"
      run chmod 755 "$binary"
      ;;
  esac

  [[ -n "${binary:-}" && -f "$binary" ]] || die "tree-sitter binary not found in ${asset}"

  run install -m 755 "$binary" "${INSTALL_BIN}.new"
  run mv -f "${INSTALL_BIN}.new" "$INSTALL_BIN"

  if ! tree_sitter_works "$INSTALL_BIN"; then
    err="$(tree_sitter_error "$INSTALL_BIN")"
    die "installed tree-sitter binary does not run (${err})"
  fi

  log "tree-sitter installed: $("$INSTALL_BIN" --version) ($INSTALL_BIN)"
}

main() {
  detect_lazyvim_arch

  if tree_sitter_works "$INSTALL_BIN"; then
    log "tree-sitter already installed: $("$INSTALL_BIN" --version) ($INSTALL_BIN)"
    return 0
  fi

  if tree_sitter_works "$(command -v tree-sitter 2>/dev/null || true)"; then
    log "using existing tree-sitter on PATH: $(command -v tree-sitter)"
    return 0
  fi

  if [[ -x "$INSTALL_BIN" ]]; then
    warn "removing broken tree-sitter at $INSTALL_BIN ($(tree_sitter_error "$INSTALL_BIN"))"
    rm -f "$INSTALL_BIN"
  fi

  install_tree_sitter_binary
}

main "$@"
