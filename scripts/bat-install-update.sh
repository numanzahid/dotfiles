#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade bat from GitHub releases.
# https://github.com/sharkdp/bat

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/bat-install-update.sh

Install or upgrade bat from GitHub releases (not apt).
https://github.com/sharkdp/bat

Installs /usr/local/bin/bat. Needs curl, jq, tar, sudo.
Invoked by ./install.sh --tools / --all and ./install-tools.sh.
On Fedora, ./install-fedora.sh --tools uses dnf bat instead.

Options:
  -h, --help   Show this help

Re-run anytime to upgrade.
EOF
}

# shellcheck source=lib/cli-args.sh
source "$SCRIPT_DIR/lib/cli-args.sh"
df_no_args_or_help "$@"

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="sharkdp/bat"
BIN_PATH="/usr/local/bin/bat"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest bat release tag" >&2
  exit 1
}

arch="$(gr_arch_gnu)"
asset="bat-${tag}-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" bat "$BIN_PATH" "$tag"

echo "Done."
echo "bat path: $(command -v bat || true)"
gr_print_version_line bat
