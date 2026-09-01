#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade Ghostty. Not part of --all.
# Fedora: not in official dnf (COPR exists; we do not use it). Build from
# official source tarball + Zig from ziglang.org.
# Ubuntu/Debian: same source build (apt lags or is missing).
#
# Re-run: ./scripts/ghostty-install-update.sh

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

REPO="ghostty-org/ghostty"
PREFIX="${HOME}/.local"
BIN="${PREFIX}/bin/ghostty"
DESKTOP="com.mitchellh.ghostty.desktop"
STAMP="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/ghostty.version"
ZIG_CACHE="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/zig"

# Ghostty pin: each series needs one Zig (https://ghostty.org/docs/install/build).
zig_for_ghostty() {
  local ver="$1"
  case "$ver" in
    1.3.*) printf '0.15.2\n' ;;
    1.2.*) printf '0.14.1\n' ;;
    1.1.* | 1.0.*) printf '0.13.0\n' ;;
    *) printf '0.15.2\n' ;;
  esac
}

linux_zig_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) printf 'x86_64\n' ;;
    aarch64 | arm64) printf 'aarch64\n' ;;
    *)
      echo "ERROR: unsupported arch for Zig: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

install_build_deps() {
  local os="$1"
  df_ensure_sudo
  case "$os" in
    fedora)
      df_run_privileged dnf install -y \
        gtk4-devel gtk4-layer-shell-devel libadwaita-devel \
        gettext pkgconf-pkg-config xz tar
      ;;
    debian)
      df_run_privileged apt-get update
      df_run_privileged apt-get install -y \
        libgtk-4-dev libadwaita-1-dev gettext libxml2-utils \
        pkg-config xz-utils tar
      df_run_privileged apt-get install -y libgtk4-layer-shell-dev || true
      ;;
  esac
}

ensure_zig() {
  local ver="$1"
  local arch tarball url dest dir alt
  arch="$(linux_zig_arch)"
  dest="${ZIG_CACHE}/${ver}"
  if [[ -x "${dest}/zig" ]]; then
    printf '%s\n' "$dest"
    return 0
  fi
  mkdir -p "$ZIG_CACHE"
  tarball="zig-linux-${arch}-${ver}.tar.xz"
  url="https://ziglang.org/download/${ver}/${tarball}"
  alt="zig-${arch}-linux-${ver}.tar.xz"
  local tmp
  tmp="$(mktemp -d)"
  if ! gr_curl -fL -o "${tmp}/zig.tar.xz" "$url"; then
    url="https://ziglang.org/download/${ver}/${alt}"
    gr_curl -fL -o "${tmp}/zig.tar.xz" "$url"
  fi
  tar -xJf "${tmp}/zig.tar.xz" -C "$tmp"
  dir="$(find "$tmp" -maxdepth 1 -type d -name 'zig-*' -print -quit)"
  [[ -n "$dir" && -x "${dir}/zig" ]] || {
    echo "ERROR: zig binary not in archive" >&2
    rm -rf "$tmp"
    exit 1
  }
  rm -rf "$dest"
  mv "$dir" "$dest"
  rm -rf "$tmp"
  printf '%s\n' "$dest"
}

install_from_source() {
  local family="$1"
  local tag ver zig_ver zig_dir src tmp extra=()
  gr_require_cmds curl jq tar xz
  tag="$(gr_latest_stable_tag "$REPO" || true)"
  [[ -n "$tag" && "$tag" != "null" ]] || {
    echo "ERROR: could not resolve latest stable ghostty tag" >&2
    exit 1
  }
  ver="${tag#v}"
  mkdir -p "$(dirname "$STAMP")"
  if [[ -f "$STAMP" ]] && [[ "$(tr -d '[:space:]' <"$STAMP")" == "$ver" ]] && [[ -x "$BIN" ]]; then
    echo "Already current: ghostty $ver"
    return 0
  fi

  echo "Ghostty $ver from official source tarball (no COPR, no distro package)"
  install_build_deps "$family"
  zig_ver="$(zig_for_ghostty "$ver")"
  zig_dir="$(ensure_zig "$zig_ver")"
  export PATH="${zig_dir}:${PATH}"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  src="${tmp}/ghostty-${ver}.tar.gz"
  gr_curl -fL -o "$src" "https://release.files.ghostty.org/${ver}/ghostty-${ver}.tar.gz"
  tar -xzf "$src" -C "$tmp"
  cd "${tmp}/ghostty-${ver}"

  if ! pkg-config --exists gtk4-layer-shell-0 2>/dev/null; then
    extra+=(-fno-sys=gtk4-layer-shell)
  fi
  "${zig_dir}/zig" build -p "$PREFIX" -Doptimize=ReleaseFast "${extra[@]}"

  printf '%s\n' "$ver" >"$STAMP"
}

os="$(df_os_family)"
case "$os" in
  fedora | debian) install_from_source "$os" ;;
  *)
    echo "ERROR: Ghostty installer supports Fedora and Ubuntu/Debian only (got $(df_host_os_id))" >&2
    exit 1
    ;;
esac

df_refresh_desktop_db
df_set_default_terminal ghostty "$DESKTOP"

echo "Done."
echo "ghostty path: $(command -v ghostty || true)"
ghostty --version 2>&1 | head -n 1 || true
