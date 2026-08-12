#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade fastfetch using official upstream methods:
# - Ubuntu 22.04+: maintainer PPA (ppa:zhangsongcui3371/fastfetch)
# - Fallback: latest .deb from GitHub releases
#
# Re-run this script anytime to upgrade.

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

  if ! ppa_configured; then
    if need_cmd add-apt-repository; then
      $SUDO add-apt-repository -y "$PPA"
    else
      echo "ERROR: add-apt-repository not found; install software-properties-common" >&2
      exit 1
    fi
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
    curl -fL --retry 3 --retry-delay 1 -o "$deb" "$url"
  else
    wget -O "$deb" "$url"
  fi

  echo "Installing: $asset"
  $SUDO apt-get install -y "$deb"
}

if use_ubuntu_ppa; then
  install_via_ppa
else
  echo "Ubuntu PPA not applicable (${os_id:-unknown} ${os_version_id:-}). Using GitHub .deb release."
  install_via_github_deb
fi

echo "Done."
echo "fastfetch path: $(command -v fastfetch || true)"
fastfetch --version | head -n 1
