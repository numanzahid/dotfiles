#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade eza from GitHub releases.
# https://github.com/eza-community/eza

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="eza-community/eza"
BIN_PATH="/usr/local/bin/eza"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO")"
[[ -n "$tag" && "$tag" != "null" ]] || {
  echo "ERROR: could not resolve latest eza release tag" >&2
  exit 1
}

arch="$(gr_arch_gnu)"
asset="eza_${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" eza "$BIN_PATH"

echo "Done."
echo "eza path: $(command -v eza || true)"
gr_print_version_line eza
