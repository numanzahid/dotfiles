#!/usr/bin/env bash
# Install official prebuilt Tree-sitter CLI (no Rust/Cargo).
# Tries the current nvim-treesitter target first, then older prebuilts that still run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/arch.sh
source "$SCRIPT_DIR/lib/arch.sh"
# shellcheck source=../scripts/lib/platform.sh
source "$SCRIPT_DIR/../scripts/lib/platform.sh"

TREE_SITTER_REPO="tree-sitter/tree-sitter"
INSTALL_BIN="${HOME}/.local/bin/tree-sitter"

TREE_SITTER_VERSION_PRIMARY="${TREE_SITTER_VERSION_PRIMARY:-0.26.11}"
TREE_SITTER_VERSION_FALLBACK="${TREE_SITTER_VERSION_FALLBACK:-0.25.6}"
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

tree_sitter_error() {
  local bin="$1"
  local err
  err="$("$bin" --version 2>&1 >/dev/null || true)"
  printf '%s' "${err:-unknown error}"
}

release_asset_name() {
  local version="$1"
  local format="$2"

  case "$format" in
    zip) printf 'tree-sitter-cli-%s.zip' "$LAZYVIM_ARCH_LABEL" ;;
    gz) printf 'tree-sitter-linux-%s.gz' "$LAZYVIM_ARCH" ;;
    *) die "unknown tree-sitter archive format: $format" ;;
  esac
}

expected_sha256() {
  local version="$1"
  local format="$2"
  local key="${version}:${LAZYVIM_ARCH_LABEL}"

  case "$format" in
    zip) printf '%s' "${TREE_SITTER_SHA256_ZIP[$key]:-}" ;;
    gz) printf '%s' "${TREE_SITTER_SHA256_GZ[$key]:-}" ;;
  esac
}

try_install_tree_sitter_release() {
  local version="$1"
  local format="$2"
  local asset url expected tmpdir archive extract_dir binary actual err

  asset="$(release_asset_name "$version" "$format")"
  url="https://github.com/${TREE_SITTER_REPO}/releases/download/v${version}/${asset}"
  expected="$(expected_sha256 "$version" "$format")"
  if [[ -z "$expected" ]]; then
    warn "no SHA256 pin for tree-sitter v${version} ${LAZYVIM_ARCH_LABEL}; skipping"
    return 1
  fi

  tmpdir="$(mktemp -d)"
  archive="${tmpdir}/${asset}"
  extract_dir="${tmpdir}/extract"
  trap '[[ -n "${tmpdir:-}" ]] && rm -rf "$tmpdir"' RETURN

  mkdir -p "${HOME}/.local/bin"
  mkdir -p "$extract_dir"

  log "trying Tree-sitter CLI v${version} (${LAZYVIM_ARCH_LABEL})"
  if ! run curl -fL --retry 3 --retry-delay 1 -o "$archive" "$url"; then
    warn "download failed for tree-sitter v${version}"
    return 1
  fi

  actual="$(sha256sum "$archive" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    die "SHA256 mismatch for ${asset} (expected ${expected}, got ${actual})"
  fi

  case "$format" in
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

  [[ -n "${binary:-}" && -f "$binary" ]] || {
    warn "tree-sitter binary not found in ${asset}"
    return 1
  }

  run install -m 755 "$binary" "${INSTALL_BIN}.new"
  run mv -f "${INSTALL_BIN}.new" "$INSTALL_BIN"

  if ! df_tree_sitter_cli_runs "$INSTALL_BIN"; then
    err="$(tree_sitter_error "$INSTALL_BIN")"
    warn "tree-sitter v${version} installed but does not run (${err})"
    rm -f "$INSTALL_BIN"
    return 1
  fi

  TREE_SITTER_SELECTED_VERSION="$version"
  return 0
}

install_tree_sitter_binary() {
  local version format
  local -a candidates=(
    "${TREE_SITTER_VERSION_PRIMARY}:zip"
    "${TREE_SITTER_VERSION_FALLBACK}:gz"
    "${TREE_SITTER_VERSION_LEGACY}:gz"
  )

  for entry in "${candidates[@]}"; do
    version="${entry%%:*}"
    format="${entry##*:}"
    if try_install_tree_sitter_release "$version" "$format"; then
      if df_tree_sitter_cli_meets_nvim_treesitter_min "$INSTALL_BIN"; then
        log "tree-sitter installed: $("$INSTALL_BIN" --version) ($INSTALL_BIN)"
      else
        warn "tree-sitter installed (degraded): $("$INSTALL_BIN" --version) ($INSTALL_BIN)"
        warn "nvim-treesitter expects CLI >= $(df_nvim_treesitter_cli_min); :checkhealth will ERROR on this host (parsers still work)"
      fi
      return 0
    fi
  done

  die "no official tree-sitter CLI prebuilt runs on this host (tried ${TREE_SITTER_VERSION_PRIMARY}, ${TREE_SITTER_VERSION_FALLBACK}, ${TREE_SITTER_VERSION_LEGACY})"
}

main() {
  detect_lazyvim_arch
  df_prepend_local_bin

  if df_tree_sitter_cli_meets_nvim_treesitter_min "$INSTALL_BIN"; then
    log "tree-sitter already installed: $("$INSTALL_BIN" --version) ($INSTALL_BIN)"
    return 0
  fi

  if [[ -x "$INSTALL_BIN" ]] && ! df_tree_sitter_cli_runs "$INSTALL_BIN"; then
    warn "removing broken tree-sitter at $INSTALL_BIN ($(tree_sitter_error "$INSTALL_BIN"))"
    rm -f "$INSTALL_BIN"
  elif df_tree_sitter_cli_degraded "$INSTALL_BIN"; then
    warn "tree-sitter v$(df_tree_sitter_cli_version "$INSTALL_BIN") runs but is below nvim-treesitter minimum; trying newer prebuilt"
  fi

  install_tree_sitter_binary
}

main "$@"
