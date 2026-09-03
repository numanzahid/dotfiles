#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade eza from GitHub releases.
# https://github.com/eza-community/eza

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/eza-install-update.sh

Install or upgrade eza from GitHub releases (not apt).
https://github.com/eza-community/eza

Installs /usr/local/bin/eza. Needs curl, jq, tar, sudo.
Invoked by ./install.sh --tools / --all and ./install-tools.sh.
On Fedora, ./install-fedora.sh --tools uses dnf eza instead.

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

REPO="eza-community/eza"
BIN_PATH="/usr/local/bin/eza"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest eza release tag" >&2
  exit 1
}

arch="$(gr_arch_gnu)"
asset="eza_${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" eza "$BIN_PATH" "$tag"

echo "Done."
echo "eza path: $(command -v eza || true)"
gr_print_version_line eza
