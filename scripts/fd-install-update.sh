#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade fd from GitHub releases.
# https://github.com/sharkdp/fd

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/fd-install-update.sh

Install or upgrade fd from GitHub releases (not apt).
https://github.com/sharkdp/fd

Installs /usr/local/bin/fd. Needs curl, jq, tar, sudo.
Invoked by ./install.sh --tools / --all and ./install-tools.sh.
On Fedora, ./install-fedora.sh --tools uses dnf fd-find instead.

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

REPO="sharkdp/fd"
BIN_PATH="/usr/local/bin/fd"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest fd release tag" >&2
  exit 1
}

arch="$(gr_arch_gnu)"
asset="fd-${tag}-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" fd "$BIN_PATH" "$tag"

echo "Done."
echo "fd path: $(command -v fd || true)"
gr_print_version_line fd
