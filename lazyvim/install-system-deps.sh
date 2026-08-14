#!/usr/bin/env bash
# Minimal apt dependencies for LazyVim (no Rust/LLVM/C++ toolchain).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/lib/privilege.sh
source "$DOTFILES_DIR/scripts/lib/privilege.sh"

APT_PACKAGES=(
  ca-certificates
  curl
  git
  unzip
  tar
  ripgrep
  fd-find
)

need_apt_package() {
  local pkg="$1"
  dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
}

install_missing_apt_packages() {
  local pkg missing=()

  for pkg in "${APT_PACKAGES[@]}"; do
  if ! need_apt_package "$pkg"; then
      missing+=("$pkg")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "system packages already satisfied"
    return 0
  fi

  log "installing apt packages: ${missing[*]}"
  df_ensure_sudo
  df_run_privileged apt-get update
  df_run_privileged apt-get install -y --no-install-recommends "${missing[@]}"

  if truthy "$APT_CLEAN_AFTER_INSTALL"; then
    df_run_privileged apt-get clean
    df_run_privileged rm -rf /var/lib/apt/lists/*
  fi
}

ensure_fd_compat() {
  if command -v fd >/dev/null 2>&1; then
    return 0
  fi

  if command -v fdfind >/dev/null 2>&1; then
    mkdir -p "${HOME}/.local/bin"
    local target
    target="$(command -v fdfind)"
    if [[ ! -e "${HOME}/.local/bin/fd" ]]; then
      log "creating ~/.local/bin/fd -> $target"
      run ln -sf "$target" "${HOME}/.local/bin/fd"
    fi
    return 0
  fi

  if command -v fd >/dev/null 2>&1; then
    return 0
  fi

  warn "fd not found; install-tools.sh installs fd, or apt install fd-find"
}

ensure_minimal_c_compiler() {
  local tmpdir src bin

  if command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1; then
    :
  else
    log "installing minimal C compiler (gcc + libc6-dev) for Tree-sitter parsers"
    df_ensure_sudo
    df_run_privileged apt-get update
    df_run_privileged apt-get install -y --no-install-recommends gcc libc6-dev
    if truthy "$APT_CLEAN_AFTER_INSTALL"; then
      df_run_privileged apt-get clean
      df_run_privileged rm -rf /var/lib/apt/lists/*
    fi
  fi

  tmpdir="$(mktemp -d)"
  src="${tmpdir}/test.c"
  bin="${tmpdir}/test"
  cat >"$src" <<'EOF'
#include <stdio.h>
int main(void) {
  return 0;
}
EOF

  local cc_cmd
  cc_cmd="$(command -v cc || command -v gcc || true)"
  [[ -n "$cc_cmd" ]] || die "no C compiler after install attempt"

  if ! "$cc_cmd" -o "$bin" "$src" 2>/dev/null; then
    rm -rf "$tmpdir"
    die "C compiler test failed; Tree-sitter parser builds will not work"
  fi

  rm -rf "$tmpdir"
  log "C compiler OK: $(command -v cc || command -v gcc)"
}

main() {
  load_install_conf
  install_missing_apt_packages
  ensure_fd_compat
  ensure_minimal_c_compiler
}

main "$@"
