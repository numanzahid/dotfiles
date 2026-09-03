#!/usr/bin/env bash
# Minimal system dependencies for LazyVim (no Rust/LLVM/C++ toolchain).
# Checks commands first; installs apt or dnf packages only when something is missing.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

DOTFILES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/lib/privilege.sh
source "$DOTFILES_DIR/scripts/lib/privilege.sh"

usage() {
  cat <<'EOF'
Usage: ./lazyvim/install-system-deps.sh [options]

Minimal system packages for LazyVim (no Rust/LLVM/C++ toolchain).
Checks commands first; installs apt or dnf packages only when missing
(ca-certificates, curl, git, unzip, tar, ripgrep, fd-find).
Ensures an fd symlink and a working C compiler for Tree-sitter parsers.

Invoked by ./lazyvim/install-lazyvim.sh. Needs sudo only if packages
are missing.

Options:
  --dry-run    Print actions without installing
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

have_ca_certs() {
  [[ -f /etc/ssl/certs/ca-certificates.crt ]] \
    || [[ -f /etc/pki/tls/certs/ca-bundle.crt ]] \
    || [[ -f /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem ]]
}

apt_clean_if_enabled() {
  if truthy "$APT_CLEAN_AFTER_INSTALL"; then
    df_run_privileged apt-get clean
    df_run_privileged rm -rf /var/lib/apt/lists/*
  fi
}

install_packages() {
  local family="$1"
  shift

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  case "$family" in
    debian)
      log "installing apt packages: $*"
      df_ensure_sudo
      df_run_privileged apt-get update
      df_run_privileged apt-get install -y --no-install-recommends "$@"
      apt_clean_if_enabled
      ;;
    fedora)
      log "installing dnf packages: $*"
      df_ensure_sudo
      df_run_privileged dnf install -y "$@"
      ;;
    *)
      die "no supported package manager (need apt-get or dnf)"
      ;;
  esac
}

# Fill nameref array with distro packages for commands that are missing.
collect_missing_packages() {
  local -n _missing="$1"
  _missing=()

  if ! have_ca_certs; then
    _missing+=(ca-certificates)
  fi
  if ! command -v curl >/dev/null 2>&1; then
    _missing+=(curl)
  fi
  if ! command -v git >/dev/null 2>&1; then
    _missing+=(git)
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    _missing+=(unzip)
  fi
  if ! command -v tar >/dev/null 2>&1; then
    _missing+=(tar)
  fi
  if ! command -v rg >/dev/null 2>&1; then
    _missing+=(ripgrep)
  fi
  if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
    _missing+=(fd-find)
  fi
}

install_missing_packages() {
  local family
  local -a missing=()
  family="$(lazyvim_pkg_family)"
  collect_missing_packages missing

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "system packages already satisfied"
    return 0
  fi

  install_packages "$family" "${missing[@]}"
}

ensure_fd_compat() {
  if command -v fd >/dev/null 2>&1; then
    return 0
  fi

  # Debian/Ubuntu fd-find ships as fdfind; Fedora fd-find already provides fd.
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

  warn "fd not found; install fd-find (apt or dnf) or run the distro tool installer"
}

ensure_minimal_c_compiler() {
  local family tmpdir src bin cc_cmd
  family="$(lazyvim_pkg_family)"

  if command -v cc >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1; then
    :
  else
    log "installing minimal C compiler for Tree-sitter parsers"
    case "$family" in
      debian)
        install_packages debian gcc libc6-dev
        ;;
      fedora)
        install_packages fedora gcc glibc-devel
        ;;
      *)
        die "no C compiler and no supported package manager"
        ;;
    esac
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
  install_missing_packages
  ensure_fd_compat
  ensure_minimal_c_compiler
}

main "$@"
