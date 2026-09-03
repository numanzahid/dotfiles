#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade Alacritty. Not part of --all.
# Fedora: dnf. Ubuntu/Debian: GitHub source tarball + rustup/cargo into ~/.local.
# Config is linked by ./install.sh and ./install-fedora.sh, not this script.
#
# Re-run: ./scripts/alacritty-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/alacritty-install-update.sh

Install or upgrade Alacritty. Not part of --all.
Fedora: dnf. Ubuntu/Debian: GitHub source tarball + rustup/cargo into
~/.local (rustup --no-modify-path, will not edit ~/.bashrc).

Sets this terminal as the default (last GUI terminal installer wins).
Needs sudo for dnf or build deps. Config is linked by ./install.sh,
not this script.

Options:
  -h, --help   Show this help

Re-run anytime to upgrade.
EOF
}

# shellcheck source=lib/cli-args.sh
source "$SCRIPT_DIR/lib/cli-args.sh"
df_no_args_or_help "$@"

# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=lib/privilege.sh
source "$SCRIPT_DIR/lib/privilege.sh"
# shellcheck source=lib/github-release.sh
source "$SCRIPT_DIR/lib/github-release.sh"
# shellcheck source=lib/gui-terminal.sh
source "$SCRIPT_DIR/lib/gui-terminal.sh"

df_prepend_local_bin

REPO="alacritty/alacritty"
PREFIX="${HOME}/.local"
BIN="${PREFIX}/bin/alacritty"
DESKTOP="Alacritty.desktop"
STAMP="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/alacritty.version"
CARGO_HOME="${CARGO_HOME:-$HOME/.cargo}"
RUSTUP_HOME="${RUSTUP_HOME:-$HOME/.rustup}"

remove_shadowing_binary() {
  local dest
  dest="${HOME}/.local/bin/alacritty"
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "remove leftover $dest (using Fedora package)"
    if command -v trash-put >/dev/null 2>&1; then
      trash-put "$dest"
    else
      rm -f "$dest"
    fi
  fi
  dest="/usr/local/bin/alacritty"
  if [[ -e "$dest" || -L "$dest" ]]; then
    echo "remove leftover $dest (using Fedora package)"
    df_run_privileged rm -f "$dest"
  fi
}

install_from_dnf() {
  local missing=0
  df_ensure_sudo
  if ! df_pkg_is_installed alacritty; then
    missing=1
  fi
  echo "Alacritty from Fedora (dnf)"
  df_run_privileged dnf install -y --setopt=install_weak_deps=False alacritty
  if [[ "$missing" -eq 1 ]]; then
    df_journal_once package-new alacritty dnf
  fi
  remove_shadowing_binary
}

install_build_deps() {
  df_ensure_sudo
  echo "Installing Alacritty build deps"
  df_run_privileged apt-get update
  df_run_privileged apt-get install -y --no-install-recommends \
    cmake g++ pkg-config python3 \
    libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev
}

ensure_rustup() {
  export CARGO_HOME RUSTUP_HOME
  export PATH="${CARGO_HOME}/bin:${PATH}"
  if [[ -x "${CARGO_HOME}/bin/rustup" ]]; then
    rustup toolchain install stable --profile minimal
    rustup default stable
    return 0
  fi
  echo "Installing rustup (stable, --no-modify-path; will not edit ~/.bashrc)"
  local tmp
  tmp="$(mktemp)"
  gr_curl -fL "https://sh.rustup.rs" -o "$tmp"
  sh "$tmp" -y --no-modify-path --default-toolchain stable --profile minimal
  rm -f "$tmp"
  # shellcheck disable=SC1091
  source "${CARGO_HOME}/env"
}

install_desktop_from_source() {
  local src_dir="$1"
  local desk src_desk dest
  src_desk="${src_dir}/extra/linux/Alacritty.desktop"
  [[ -f "$src_desk" ]] || return 0
  dest="${XDG_DATA_HOME:-$HOME/.local/share}/applications/${DESKTOP}"
  mkdir -p "$(dirname "$dest")"
  desk="$(mktemp)"
  sed -e "s|^TryExec=alacritty|TryExec=${BIN}|" \
    -e "s|^Exec=alacritty|Exec=${BIN}|" \
    "$src_desk" >"$desk"
  cp -f "$desk" "$dest"
  rm -f "$desk"
  df_journal_once copy "$dest" "$src_desk"
  if [[ -f "${src_dir}/extra/logo/alacritty-term.svg" ]]; then
    df_ensure_user_icon Alacritty.svg "${src_dir}/extra/logo/alacritty-term.svg"
  fi
}

install_terminfo_user() {
  local src_dir="$1"
  if infocmp alacritty >/dev/null 2>&1; then
    return 0
  fi
  [[ -f "${src_dir}/extra/alacritty.info" ]] || return 0
  mkdir -p "${HOME}/.terminfo"
  tic -xe alacritty,alacritty-direct "${src_dir}/extra/alacritty.info"
}

install_from_source() {
  local tag ver tmp src_dir
  gr_require_cmds curl jq tar
  tag="$(gr_latest_tag "$REPO" || true)"
  [[ -n "$tag" && "$tag" != "null" ]] || {
    echo "ERROR: could not resolve latest alacritty tag" >&2
    exit 1
  }
  ver="${tag#v}"
  mkdir -p "$(dirname "$STAMP")"
  if [[ -f "$STAMP" ]] && [[ "$(tr -d '[:space:]' <"$STAMP")" == "$ver" ]] && [[ -x "$BIN" ]]; then
    echo "Already current: alacritty $ver"
    return 0
  fi

  echo "Alacritty $ver from GitHub source"
  install_build_deps
  ensure_rustup

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if ! gr_download "https://github.com/${REPO}/archive/refs/tags/${tag}.tar.gz" "${tmp}/alacritty.tar.gz"; then
    rm -rf "$tmp"
    trap - RETURN
    gr_exit_if_keeping "$BIN" "GitHub download failed"
    echo "ERROR: download failed" >&2
    exit 1
  fi
  tar -xzf "${tmp}/alacritty.tar.gz" -C "$tmp"
  src_dir="$(find "$tmp" -maxdepth 1 -type d -name 'alacritty-*' -print -quit)"
  [[ -n "$src_dir" && -f "${src_dir}/Cargo.toml" ]] || {
    echo "ERROR: Cargo.toml not in source tarball" >&2
    exit 1
  }

  (
    cd "$src_dir"
    cargo build --release
  )
  [[ -x "${src_dir}/target/release/alacritty" ]] || {
    echo "ERROR: cargo build did not produce alacritty" >&2
    exit 1
  }

  mkdir -p "$(dirname "$BIN")"
  install -m 755 "${src_dir}/target/release/alacritty" "$BIN"
  gr_track_path "$BIN"
  df_journal_once binary "$BIN" "$tag"

  install_desktop_from_source "$src_dir"
  install_terminfo_user "$src_dir"

  printf '%s\n' "$ver" >"$STAMP"
  gr_track_path "$STAMP"
}

os="$(df_os_family)"
case "$os" in
  fedora) install_from_dnf ;;
  debian) install_from_source ;;
  *)
    echo "ERROR: Alacritty installer supports Fedora and Ubuntu/Debian only (got $(df_host_os_id))" >&2
    exit 1
    ;;
esac

df_refresh_desktop_db
df_set_default_terminal alacritty "$DESKTOP"

echo "Done."
echo "alacritty path: $(command -v alacritty || true)"
gr_print_version_line alacritty
