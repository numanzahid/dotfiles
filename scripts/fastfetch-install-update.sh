#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade fastfetch from GitHub releases (never apt, never PPA).
# https://github.com/fastfetch-cli/fastfetch
#
# Removes an apt/PPA fastfetch and the zhangsongcui3371 PPA + keys, then
# installs the official tarball to /usr/local/bin/fastfetch.
#
# Re-run anytime to upgrade.
# Invoked by: ./install-fetch.sh fastfetch
# Light host: ~/.install-scripts/fastfetch-install-update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/fastfetch-install-update.sh

Install or upgrade fastfetch from GitHub releases (never apt, never PPA).
https://github.com/fastfetch-cli/fastfetch

Removes an apt/PPA fastfetch if present, then installs
/usr/local/bin/fastfetch. Needs curl, jq, tar, sudo.

Prefer ./install-fetch.sh on a workstation (config + art + binary).
On a light host, ./install-copy/install.sh --fetch copies this script to
~/.install-scripts/fastfetch-install-update.sh for later upgrades.

Options:
  -h, --help   Show this help

Re-run anytime to upgrade the binary only.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi
if [[ $# -gt 0 ]]; then
  echo "Unknown option: $1" >&2
  usage >&2
  exit 1
fi

# shellcheck disable=SC1091
if [[ -f "$SCRIPT_DIR/lib/github-release.sh" ]]; then
  source "$SCRIPT_DIR/lib/github-release.sh"
elif [[ -f "$SCRIPT_DIR/fastfetch-install-update.lib.sh" ]]; then
  source "$SCRIPT_DIR/fastfetch-install-update.lib.sh"
else
  echo "ERROR: github-release helper not found next to this script" >&2
  exit 1
fi

REPO="fastfetch-cli/fastfetch"
BIN_PATH="/usr/local/bin/fastfetch"
PPA="ppa:zhangsongcui3371/fastfetch"

gr_require_cmds curl jq tar

linux_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "aarch64" ;;
    armv7l) echo "armv7l" ;;
    i686 | i386) echo "i686" ;;
    *)
      echo "ERROR: unsupported architecture for fastfetch: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

remove_fastfetch_ppa() {
  if ! command -v apt-get >/dev/null 2>&1; then
    return 0
  fi

  local sudo_cmd f changed=0
  sudo_cmd="$(gr_sudo)"

  if command -v add-apt-repository >/dev/null 2>&1; then
    if grep -rq 'zhangsongcui3371' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
      echo "Removing fastfetch PPA: $PPA"
      $sudo_cmd add-apt-repository -y --remove "$PPA" || true
      changed=1
    fi
  fi

  if [[ -f /etc/apt/sources.list ]] && grep -q 'zhangsongcui3371' /etc/apt/sources.list; then
    echo "Removing zhangsongcui3371 line from /etc/apt/sources.list"
    $sudo_cmd sed -i '/zhangsongcui3371/d' /etc/apt/sources.list
    changed=1
  fi

  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    echo "Removing apt source: $f"
    $sudo_cmd rm -f "$f"
    changed=1
  done < <(grep -rl 'zhangsongcui3371' /etc/apt/sources.list.d 2>/dev/null || true)

  for f in \
    /etc/apt/sources.list.d/zhangsongcui3371* \
    /etc/apt/trusted.gpg.d/zhangsongcui3371* \
    /etc/apt/keyrings/zhangsongcui3371* \
    /usr/share/keyrings/zhangsongcui3371*; do
    if [[ -e "$f" || -L "$f" ]]; then
      echo "Removing apt source/key: $f"
      $sudo_cmd rm -f "$f"
      changed=1
    fi
  done

  if [[ "$changed" -eq 1 ]]; then
    echo "Refreshing apt lists after PPA removal..."
    $sudo_cmd apt-get update
  fi
}

remove_apt_fastfetch() {
  if ! command -v dpkg-query >/dev/null 2>&1; then
    return 0
  fi

  local pkg="fastfetch" sudo_cmd
  if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
    return 0
  fi

  echo "Removing apt fastfetch (PPA or .deb) to avoid conflicts"
  sudo_cmd="$(gr_sudo)"
  $sudo_cmd apt-get remove -y "$pkg"
}

remove_fastfetch_ppa
remove_apt_fastfetch

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest fastfetch release tag" >&2
  exit 1
}

arch="$(linux_arch)"
asset="fastfetch-linux-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" fastfetch "$BIN_PATH" "$tag"

echo "Done."
echo "fastfetch path: $(command -v fastfetch || true)"
gr_print_version_line fastfetch
