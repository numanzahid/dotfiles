#!/usr/bin/env bash
set -euo pipefail

# Installs latest Neovim stable release from GitHub (never apt).
# Downloads the official release tarball into /opt, then symlinks:
#   /opt/nvim -> /opt/nvim-<version>-<arch>
#   /usr/local/bin/nvim -> /opt/nvim/bin/nvim
#
# Re-run anytime to upgrade.

REPO="neovim/neovim"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
if [[ -f "$SCRIPT_DIR/lib/github-release.sh" ]]; then
  source "$SCRIPT_DIR/lib/github-release.sh"
elif [[ -f "$SCRIPT_DIR/neovim-install-update.lib.sh" ]]; then
  source "$SCRIPT_DIR/neovim-install-update.lib.sh"
else
  echo "ERROR: github-release helper not found next to this script" >&2
  exit 1
fi

need_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! need_cmd curl && ! need_cmd wget; then
  echo "ERROR: need curl or wget" >&2
  exit 1
fi
if ! need_cmd tar; then
  echo "ERROR: need tar" >&2
  exit 1
fi

ARCH_RAW="$(uname -m)"
case "$ARCH_RAW" in
x86_64 | amd64) ASSET="nvim-linux-x86_64.tar.gz" ;;
aarch64 | arm64) ASSET="nvim-linux-arm64.tar.gz" ;;
*)
  echo "ERROR: unsupported architecture: $ARCH_RAW" >&2
  echo "Supported: x86_64/amd64, aarch64/arm64" >&2
  exit 1
  ;;
esac

URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if need_cmd sudo; then
    SUDO="sudo"
  else
    echo "ERROR: need root or sudo to install into /opt and /usr/local/bin" >&2
    exit 1
  fi
fi

remove_apt_neovim() {
  if ! command -v dpkg-query >/dev/null 2>&1; then
    return 0
  fi

  local pkg pkgs=()
  for pkg in neovim neovim-nox neovim-qt; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      pkgs+=("$pkg")
    fi
  done

  if ((${#pkgs[@]} > 0)); then
    echo "Removing apt neovim packages to avoid conflicts: ${pkgs[*]}"
    $SUDO apt-get remove -y "${pkgs[@]}"
  fi
}

tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT

tarball="${tmpdir}/${ASSET}"
NVIM_BIN="${NVIM_BIN:-/usr/local/bin/nvim}"

echo "Downloading: $URL"
download_ok=1
final_url=""
if need_cmd curl; then
  final_url="$(gr_curl -fL -o "$tarball" -w '%{url_effective}' "$URL")" || download_ok=0
else
  gr_wget -O "$tarball" "$URL" || download_ok=0
fi

if [[ "$download_ok" -ne 1 || ! -s "$tarball" ]]; then
  gr_exit_if_keeping "$NVIM_BIN" "GitHub download failed"
  echo "ERROR: download failed: $URL" >&2
  exit 1
fi

if [[ -n "${final_url:-}" ]]; then
  gr_verify_or_continue "$tarball" "$final_url"
else
  echo "No redirect URL for checksum lookup; continuing"
fi

remove_apt_neovim

version="latest"
if [[ -n "${final_url:-}" ]]; then
  # Example final URL includes: /download/v0.11.5/nvim-linux-x86_64.tar.gz
  if [[ "$final_url" =~ /download/(v[0-9]+\.[0-9]+\.[0-9]+)/ ]]; then
    version="${BASH_REMATCH[1]}"
  fi
fi

extract_dir="${tmpdir}/extract"
mkdir -p "$extract_dir"
tar -xzf "$tarball" -C "$extract_dir"

# The tarball extracts to a single top-level directory like "nvim-linux-x86_64"
topdir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "${topdir:-}" ]]; then
  echo "ERROR: could not find extracted directory" >&2
  exit 1
fi

install_dir="/opt/nvim-${version}-${ARCH_RAW}"
symlink_dir="/opt/nvim"

echo "Installing to: $install_dir"
$SUDO mkdir -p /opt

# Adopt the current /opt/nvim target if this installer created it.
current=""
if [[ -L "$symlink_dir" ]]; then
  current="$(readlink -f "$symlink_dir" 2>/dev/null || true)"
  if [[ -n "$current" && "$current" == /opt/nvim-* && -d "$current" ]]; then
    gr_track_path "$current"
  fi
fi

# Replace this versioned dir only (we are about to install here).
$SUDO rm -rf "$install_dir"
$SUDO mv "$topdir" "$install_dir"
gr_track_path "$install_dir"

# Update symlink /opt/nvim -> install_dir (atomic-ish).
$SUDO ln -sfn "$install_dir" "$symlink_dir"

# Drop older trees this installer recorded. Leave anything else in /opt.
old_nullglob=0
if shopt -q nullglob; then
  old_nullglob=1
fi
shopt -s nullglob
for old in /opt/nvim-*; do
  if [[ "$old" == "$install_dir" || -L "$old" ]]; then
    continue
  fi
  if gr_path_is_tracked "$old"; then
    echo "Removing old neovim tree we installed: $old"
    $SUDO rm -rf "$old"
  else
    echo "Leaving unmanaged neovim tree: $old"
  fi
done
if [[ "$old_nullglob" -eq 0 ]]; then
  shopt -u nullglob
fi

# Ensure /usr/local/bin/nvim points to the current /opt/nvim/bin/nvim
$SUDO mkdir -p /usr/local/bin
$SUDO ln -sfn "${symlink_dir}/bin/nvim" /usr/local/bin/nvim
if declare -F df_journal_once >/dev/null 2>&1; then
  df_journal_once opt-tree "$install_dir"
  df_journal_once symlink "$symlink_dir"
  df_journal_once binary /usr/local/bin/nvim
fi

echo "Done."
echo "nvim path: $(command -v nvim || true)"
echo "nvim version:"
nvim --version 2>&1 | head -n 2 || true
