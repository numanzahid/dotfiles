#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade btop from GitHub releases.
# Debian/Ubuntu apt often ships an older btop than our config expects.
# https://github.com/aristocratos/btop

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="aristocratos/btop"
BIN_PATH="/usr/local/bin/btop"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO")"
[[ -n "$tag" && "$tag" != "null" ]] || {
  echo "ERROR: could not resolve latest btop release tag" >&2
  exit 1
}

arch="$(gr_arch_musl)"
asset="btop-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" btop "$BIN_PATH"

echo "Done."
echo "btop path: $(command -v btop || true)"
btop --version | head -n 1
