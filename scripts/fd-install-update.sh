#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade fd from GitHub releases.
# https://github.com/sharkdp/fd

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="sharkdp/fd"
BIN_PATH="/usr/local/bin/fd"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO")"
[[ -n "$tag" && "$tag" != "null" ]] || {
  echo "ERROR: could not resolve latest fd release tag" >&2
  exit 1
}

arch="$(gr_arch_gnu)"
asset="fd-${tag}-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" fd "$BIN_PATH"

echo "Done."
echo "fd path: $(command -v fd || true)"
fd --version | head -n 1
