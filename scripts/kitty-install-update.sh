#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade Kitty. Not part of --all.
# GitHub Linux tarball into ~/.local/kitty.app (symlink kitty + kitten).
# Config is linked by ./install.sh and ./install-fedora.sh, not this script.
#
# Re-run: ./scripts/kitty-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=lib/privilege.sh
source "$SCRIPT_DIR/lib/privilege.sh"
# shellcheck source=lib/github-release.sh
source "$SCRIPT_DIR/lib/github-release.sh"
# shellcheck source=lib/gui-terminal.sh
source "$SCRIPT_DIR/lib/gui-terminal.sh"

df_prepend_local_bin

REPO="kovidgoyal/kitty"
APP="${HOME}/.local/kitty.app"
BIN="${HOME}/.local/bin/kitty"
KITTEN="${HOME}/.local/bin/kitten"
DESKTOP="kitty.desktop"
STAMP="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/kitty.version"

linux_kitty_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) printf 'x86_64\n' ;;
    aarch64 | arm64) printf 'arm64\n' ;;
    *)
      echo "ERROR: unsupported arch for kitty: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

ensure_xz() {
  command -v xz >/dev/null 2>&1 && return 0
  df_ensure_sudo
  case "$(df_os_family)" in
    fedora)
      df_run_privileged dnf install -y --setopt=install_weak_deps=False xz
      ;;
    debian)
      df_run_privileged apt-get update
      df_run_privileged apt-get install -y --no-install-recommends xz-utils
      ;;
    *)
      echo "ERROR: need xz" >&2
      exit 1
      ;;
  esac
}

trash_or_rm() {
  local path="$1"
  [[ -e "$path" || -L "$path" ]] || return 0
  if command -v trash-put >/dev/null 2>&1; then
    trash-put "$path"
  else
    rm -rf "$path"
  fi
}

install_desktop() {
  local src dest icon exec_path
  src="${APP}/share/applications/kitty.desktop"
  [[ -f "$src" ]] || return 0
  dest="${XDG_DATA_HOME:-$HOME/.local/share}/applications/${DESKTOP}"
  mkdir -p "$(dirname "$dest")"
  exec_path="${APP}/bin/kitty"
  icon="${APP}/share/icons/hicolor/256x256/apps/kitty.png"
  [[ -f "$icon" ]] || icon="kitty"
  sed -e "s|^Exec=kitty|Exec=${exec_path}|" \
    -e "s|^TryExec=kitty|TryExec=${exec_path}|" \
    -e "s|^Icon=kitty|Icon=${icon}|" \
    "$src" >"$dest"
  df_journal_once copy "$dest" "$src"
}

install_from_github() {
  local tag ver arch url tmp extract
  gr_require_cmds curl jq tar
  tag="$(gr_latest_tag "$REPO" || true)"
  [[ -n "$tag" && "$tag" != "null" ]] || {
    echo "ERROR: could not resolve latest kitty tag" >&2
    exit 1
  }
  ver="${tag#v}"
  mkdir -p "$(dirname "$STAMP")"
  if [[ -f "$STAMP" ]] && [[ "$(tr -d '[:space:]' <"$STAMP")" == "$ver" ]] && [[ -x "${APP}/bin/kitty" ]] && [[ -x "$BIN" ]]; then
    echo "Already current: kitty $ver"
    return 0
  fi

  arch="$(linux_kitty_arch)"
  url="https://github.com/${REPO}/releases/download/${tag}/kitty-${ver}-${arch}.txz"
  echo "Kitty $ver from GitHub"
  ensure_xz

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if ! gr_download "$url" "${tmp}/kitty.txz"; then
    rm -rf "$tmp"
    trap - RETURN
    gr_exit_if_keeping "${APP}/bin/kitty" "GitHub download failed"
    echo "ERROR: download failed: $url" >&2
    exit 1
  fi

  extract="${tmp}/kitty.app"
  mkdir -p "$extract"
  tar -xJf "${tmp}/kitty.txz" -C "$extract"
  [[ -x "${extract}/bin/kitty" ]] || {
    echo "ERROR: kitty binary not in tarball" >&2
    exit 1
  }

  mkdir -p "$(dirname "$APP")" "$(dirname "$BIN")"
  if [[ -e "$APP" || -L "$APP" ]]; then
    trash_or_rm "$APP"
  fi
  mv "$extract" "$APP"

  ln -sfn "${APP}/bin/kitty" "$BIN"
  ln -sfn "${APP}/bin/kitten" "$KITTEN"
  gr_track_path "$APP"
  gr_track_path "$BIN"
  gr_track_path "$KITTEN"
  df_journal_once binary "$APP" "$tag"

  install_desktop

  printf '%s\n' "$ver" >"$STAMP"
  gr_track_path "$STAMP"
}

os="$(df_os_family)"
case "$os" in
  fedora | debian) install_from_github ;;
  *)
    echo "ERROR: Kitty installer supports Fedora and Ubuntu/Debian only (got $(df_host_os_id))" >&2
    exit 1
    ;;
esac

df_refresh_desktop_db
df_set_default_terminal kitty "$DESKTOP"

echo "Done."
echo "kitty path: $(command -v kitty || true)"
gr_print_version_line kitty
