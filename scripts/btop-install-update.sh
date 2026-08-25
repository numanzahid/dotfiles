#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade btop from official GitHub releases (never apt).
#   https://github.com/aristocratos/btop
#
# Installs to /usr/local/bin/btop
# Re-run anytime to upgrade.
# Invoked by: ./install.sh --btop  (or --all)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="aristocratos/btop"
BIN_PATH="/usr/local/bin/btop"

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
