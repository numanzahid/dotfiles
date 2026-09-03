#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade btop from official GitHub releases (never apt).
#   https://github.com/aristocratos/btop
#
# Installs to /usr/local/bin/btop
# Re-run anytime to upgrade.
# Invoked by: ./install.sh --btop  (or --all)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/btop-install-update.sh

Install or upgrade btop from GitHub releases (never apt).
https://github.com/aristocratos/btop

Installs /usr/local/bin/btop. Removes an apt btop if present.
Needs curl, jq, tar, sudo.
Invoked by ./install.sh --btop / --all.
On Fedora, ./install-fedora.sh --btop uses the dnf package instead.

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
