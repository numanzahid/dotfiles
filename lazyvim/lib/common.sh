#!/usr/bin/env bash
# Shared helpers for the lean LazyVim installer.
set -euo pipefail

LAZYVIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="$(cd "$LAZYVIM_DIR/.." && pwd)"
NVIM_CONFIG_DIR="$DOTFILES_DIR/home/.config/nvim"
INSTALL_CONF="${LAZYVIM_INSTALL_CONF:-$LAZYVIM_DIR/install.conf}"

: "${DRY_RUN:=0}"
FAILED=0

log() {
  printf '[lazyvim] %s\n' "$*"
}

warn() {
  printf '[lazyvim] WARN: %s\n' "$*" >&2
}

die() {
  printf '[lazyvim] ERROR: %s\n' "$*" >&2
  exit 1
}

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

load_install_conf() {
  # Environment variables set on the command line win over install.conf.
  local env_allow_root="${LAZYVIM_ALLOW_ROOT+set}"
  local env_allow_root_val="${LAZYVIM_ALLOW_ROOT:-}"

  if [[ -f "$INSTALL_CONF" ]]; then
    # shellcheck disable=SC1090
    source "$INSTALL_CONF"
  fi

  if [[ -n "$env_allow_root" ]]; then
    LAZYVIM_ALLOW_ROOT="$env_allow_root_val"
  else
    : "${LAZYVIM_ALLOW_ROOT:=false}"
  fi

  : "${ENABLE_DOCKER:=true}"
  : "${ENABLE_MARKDOWN_TOOLS:=false}"
  : "${ENABLE_VUE:=false}"
  : "${ENABLE_SVELTE:=false}"
  : "${ENABLE_ASTRO:=false}"
  : "${ENABLE_ANGULAR:=false}"
  : "${REQUIRE_NODE:=true}"
  : "${APT_CLEAN_AFTER_INSTALL:=true}"
}

truthy() {
  case "${1,,}" in
    1 | true | yes | on) return 0 ;;
    *) return 1 ;;
  esac
}

check_platform() {
  case "$(uname -s)" in
    Linux) ;;
    *)
      die "unsupported OS: $(uname -s) (Linux only)"
      ;;
  esac

  if ! command -v apt-get >/dev/null 2>&1; then
    die "apt-get not found (Debian/Ubuntu-like systems only)"
  fi
}

check_not_root_for_user_phase() {
  if [[ "$(id -u)" -eq 0 && -n "${SUDO_USER:-}" ]]; then
    log "dropping to user $SUDO_USER for LazyVim setup"
  exec sudo -u "$SUDO_USER" -H env LAZYVIM_INSTALL_CONF="$INSTALL_CONF" "$0" "$@"
  fi

  if [[ "$(id -u)" -eq 0 ]] && ! truthy "$LAZYVIM_ALLOW_ROOT"; then
    die "run as your normal user, not root. For root-only hosts: LAZYVIM_ALLOW_ROOT=true $0 (or set LAZYVIM_ALLOW_ROOT=true in lazyvim/install.conf)"
  fi

  if [[ "$(id -u)" -eq 0 ]]; then
    warn "running LazyVim setup as root (LAZYVIM_ALLOW_ROOT=true)"
  fi
}

ensure_local_bin_path() {
  case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *)
      warn "~/.local/bin is not in PATH; add: export PATH=\"\$HOME/.local/bin:\$PATH\""
      ;;
  esac
}

command_version() {
  local cmd="$1"
  shift
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" "$@" 2>/dev/null | head -n 1
  else
    echo "missing"
  fi
}

disk_usage_bytes() {
  local path="$1"
  if [[ -e "$path" ]]; then
    du -sb "$path" 2>/dev/null | awk '{print $1}'
  else
    echo 0
  fi
}

format_bytes() {
  local bytes="$1"
  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec-i --suffix=B "$bytes"
  else
    printf '%s bytes' "$bytes"
  fi
}

record_fail() {
  FAILED=1
  warn "$1"
}
