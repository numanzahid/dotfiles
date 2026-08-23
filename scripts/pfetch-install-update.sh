#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade pfetch from the official GitHub repo:
#   https://github.com/dylanaraps/pfetch
#
# Installs the pfetch script to /usr/local/bin/pfetch
# and keeps a git checkout in /opt/pfetch for updates.
#
# Re-run this script anytime to upgrade.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="dylanaraps/pfetch"
INSTALL_DIR="/opt/pfetch"
BIN_PATH="/usr/local/bin/pfetch"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

for cmd in git curl jq; do
  if ! need_cmd "$cmd"; then
    echo "ERROR: need $cmd" >&2
    exit 1
  fi
done

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if need_cmd sudo; then
    SUDO="sudo"
  else
    echo "ERROR: need root or sudo" >&2
    exit 1
  fi
fi

latest_tag() {
  gr_latest_tag "$REPO"
}

version="latest"
tag="$(latest_tag)"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  echo "ERROR: could not resolve latest pfetch release tag" >&2
  exit 1
fi
version="$tag"

if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "Updating existing checkout in $INSTALL_DIR"
  $SUDO git -C "$INSTALL_DIR" fetch --tags origin
  $SUDO git -C "$INSTALL_DIR" checkout -f "$tag"
else
  echo "Cloning pfetch $tag into $INSTALL_DIR"
  $SUDO mkdir -p "$(dirname "$INSTALL_DIR")"
  $SUDO rm -rf "$INSTALL_DIR"
  $SUDO git clone --depth 1 --branch "$tag" "https://github.com/${REPO}.git" "$INSTALL_DIR"
fi

if [[ ! -f "$INSTALL_DIR/pfetch" ]]; then
  echo "ERROR: pfetch script not found in $INSTALL_DIR" >&2
  exit 1
fi

echo "Installing $BIN_PATH"
$SUDO install -m 755 "$INSTALL_DIR/pfetch" "$BIN_PATH"

echo "Done."
echo "pfetch path: $(command -v pfetch || true)"
echo "pfetch version tag: $version"
echo "config: \${PF_SOURCE:-unset} (set in ~/.shell_aliases_interactive.sh)"
pfetch 2>/dev/null | head -n 5 || true
