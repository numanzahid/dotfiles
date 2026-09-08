#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade eza from GitHub releases.
# https://github.com/eza-community/eza

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/eza"

usage() {
  cat <<'EOF'
Usage: ./scripts/eza-install-update.sh [options]

Install or upgrade eza from GitHub releases (not apt).
https://github.com/eza-community/eza

Installs /usr/local/bin/eza. Needs curl, jq, tar, sudo.
Invoked by ./devbox.sh --tools / --all and ./install-tools.sh.
On Fedora, ./desktop.sh --tools uses dnf eza instead.

Options:
  --uninstall  Remove installed binary and journaled paths
  --dry-run    Show actions only
  --yes, -y    Skip confirmation (with --uninstall)
  -h, --help   Show this help

Re-run anytime to upgrade.
EOF
}


# shellcheck source=lib/install-cli.sh
source "$SCRIPT_DIR/lib/install-cli.sh"
# shellcheck source=lib/software-uninstall.sh
source "$SCRIPT_DIR/lib/software-uninstall.sh"

uninstall_eza() {
  df_inst_remove_github_binary eza "$BIN_PATH"
  df_inst_remove_package eza
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall eza uninstall_eza; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="eza-community/eza"

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
