#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade starship from GitHub releases.
# https://github.com/starship/starship

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/github-release.sh
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="starship/starship"
BIN_PATH="/usr/local/bin/starship"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest starship release tag" >&2
  exit 1
}

arch="$(gr_arch_musl)"
asset="starship-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" starship "$BIN_PATH" "$tag"

echo "Done."
echo "starship path: $(command -v starship || true)"
gr_print_version_line starship
