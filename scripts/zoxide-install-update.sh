#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade zoxide from GitHub releases.
# https://github.com/ajeetdsouza/zoxide

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/zoxide-install-update.sh

Install or upgrade zoxide from GitHub releases (not apt).
https://github.com/ajeetdsouza/zoxide

Installs /usr/local/bin/zoxide. Needs curl, jq, tar, sudo.
Invoked by ./install.sh --tools / --all, ./install-tools.sh, and
./install-fedora.sh --tools (Fedora has no zoxide in dnf).

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

REPO="ajeetdsouza/zoxide"
BIN_PATH="/usr/local/bin/zoxide"

gr_require_cmds curl jq tar

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest zoxide release tag" >&2
  exit 1
}

version="${tag#v}"
arch="$(gr_arch_musl)"
asset="zoxide-${version}-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" zoxide "$BIN_PATH" "$tag"

echo "Done."
echo "zoxide path: $(command -v zoxide || true)"
gr_print_version_line zoxide
