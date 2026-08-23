#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade fastfetch using official upstream methods:
# - Ubuntu 22.04+: maintainer PPA (ppa:zhangsongcui3371/fastfetch)
# - Fallback: latest .deb from GitHub releases
#
# Re-run this script anytime to upgrade.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="fastfetch-cli/fastfetch"
PPA="ppa:zhangsongcui3371/fastfetch"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! need_cmd curl && ! need_cmd wget; then
  echo "ERROR: need curl or wget" >&2
  exit 1
fi

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if need_cmd sudo; then
    SUDO="sudo"
  else
    echo "ERROR: need root or sudo" >&2
    exit 1
  fi
fi

os_id=""
os_version_id=""
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  source /etc/os-release
  os_id="${ID:-}"
  os_version_id="${VERSION_ID:-}"
fi

ppa_configured() {
  grep -rq 'zhangsongcui3371/fastfetch' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null
}

use_ubuntu_ppa() {
  [[ "$os_id" == "ubuntu" ]] || return 1
  [[ -n "$os_version_id" ]] || return 1

  local major="${os_version_id%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]] || return 1
  (( major >= 22 ))
}

install_via_ppa() {
  echo "Using official fastfetch PPA on Ubuntu: $PPA"

  if ! need_cmd add-apt-repository; then
    echo "add-apt-repository not found; installing software-properties-common..."
    $SUDO apt-get update
    $SUDO apt-get install -y software-properties-common
  fi

  if ! ppa_configured; then
    $SUDO add-apt-repository -y "$PPA"
  else
    echo "PPA already configured."
  fi

  $SUDO apt-get update
  $SUDO apt-get install -y fastfetch
}

install_via_github_deb() {
  local arch_raw arch asset url deb tmpdir

  arch_raw="$(uname -m)"
  case "$arch_raw" in
    x86_64 | amd64) arch="amd64" ;;
    aarch64 | arm64) arch="aarch64" ;;
    *)
      echo "ERROR: unsupported architecture for .deb install: $arch_raw" >&2
      exit 1
      ;;
  esac

  asset="fastfetch-linux-${arch}.deb"
  url="https://github.com/${REPO}/releases/latest/download/${asset}"

  tmpdir="$(mktemp -d)"
  trap "rm -rf '${tmpdir}'" EXIT

  deb="${tmpdir}/${asset}"

  echo "Downloading: $url"
  if need_cmd curl; then
    gr_curl -fL -o "$deb" "$url"
  else
    gr_wget -O "$deb" "$url"
  fi

  echo "Installing: $asset"
  $SUDO apt-get install -y "$deb"
}

if use_ubuntu_ppa; then
  set +e
  install_via_ppa
  ppa_rc=$?
  set -e
  if [[ "$ppa_rc" -ne 0 ]]; then
    echo "Ubuntu PPA install failed; falling back to GitHub .deb release."
    install_via_github_deb
  fi
else
  echo "Ubuntu PPA not applicable (${os_id:-unknown} ${os_version_id:-}). Using GitHub .deb release."
  install_via_github_deb
fi

echo "Done."
echo "fastfetch path: $(command -v fastfetch || true)"
fastfetch --version 2>&1 | head -n 1 || true
