#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade btop from official GitHub releases (never apt).
#   https://github.com/aristocratos/btop
#
# Installs to /usr/local/bin/btop
# Re-run anytime to upgrade.
# Invoked by: ./devbox.sh --btop  (or --all)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/btop"

usage() {
  cat <<'EOF'
Usage: ./scripts/btop-install-update.sh [options]

Install or upgrade btop from GitHub releases (never apt).
https://github.com/aristocratos/btop

Installs /usr/local/bin/btop. Removes an apt btop if present.
Needs curl, jq, tar, sudo.
Invoked by ./devbox.sh --btop / --all.
On Fedora, ./desktop.sh --btop uses the dnf package instead.

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

uninstall_btop() {
  df_inst_remove_btop
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall btop uninstall_btop; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="aristocratos/btop"

gr_require_cmds curl jq tar

remove_apt_btop() {
  if ! command -v dpkg-query >/dev/null 2>&1; then
    return 0
  fi

  local pkg pkgs=() sudo_cmd
  for pkg in btop; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      pkgs+=("$pkg")
    fi
  done

  if ((${#pkgs[@]} > 0)); then
    echo "Removing apt btop packages to avoid conflicts: ${pkgs[*]}"
    sudo_cmd="$(gr_sudo)"
    $sudo_cmd apt-get remove -y "${pkgs[@]}"
  fi
}

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest btop release tag" >&2
  exit 1
}

arch="$(gr_arch_musl)"
asset="btop-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

gr_install_from_targz "$url" btop "$BIN_PATH" "$tag"
remove_apt_btop

echo "Done."
echo "btop path: $(command -v btop || true)"
gr_print_version_line btop
