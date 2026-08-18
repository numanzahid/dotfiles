#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade zoxide from GitHub releases.
# https://github.com/ajeetdsouza/zoxide

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="ajeetdsouza/zoxide"
BIN_PATH="/usr/local/bin/zoxide"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO")"
[[ -n "$tag" && "$tag" != "null" ]] || {
  echo "ERROR: could not resolve latest zoxide release tag" >&2
  exit 1
}

version="${tag#v}"
arch="$(gr_arch_musl)"
asset="zoxide-${version}-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" zoxide "$BIN_PATH"

echo "Done."
echo "zoxide path: $(command -v zoxide || true)"
gr_print_version_line zoxide
