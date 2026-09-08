#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade starship from GitHub releases.
# https://github.com/starship/starship

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/starship"

usage() {
  cat <<'EOF'
Usage: ./scripts/starship-install-update.sh [options]

Install or upgrade starship from GitHub releases (not dnf/apt).
https://github.com/starship/starship

Installs /usr/local/bin/starship. Needs curl, jq, tar, sudo.
Invoked by ./desktop.sh --starship / --all (default Fedora prompt).
Not part of Debian ./devbox.sh --all (Debian uses the custom prompt).

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

uninstall_starship() {
  df_inst_remove_github_binary starship "$BIN_PATH"
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall starship uninstall_starship; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac
# shellcheck source=scripts/lib/github-release.sh
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="starship/starship"

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
