#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade lazygit from official GitHub releases:
#   https://github.com/jesseduffield/lazygit
#
# Installs to /usr/local/bin/lazygit
# Re-run anytime to upgrade.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/lazygit"

usage() {
  cat <<'EOF'
Usage: ./scripts/lazygit-install-update.sh [options]

Install or upgrade lazygit from GitHub releases (not apt).
https://github.com/jesseduffield/lazygit

Installs /usr/local/bin/lazygit. Needs curl, jq, tar, sudo.
Invoked by ./devbox.sh --lazygit / --all and ./desktop.sh --lazygit
(not in Fedora repos). Not part of copy-install.

Options:
  --uninstall  Remove /usr/local/bin/lazygit and journaled paths
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

uninstall_lazygit() {
  df_inst_remove_github_binary lazygit "$BIN_PATH"
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall lazygit uninstall_lazygit; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="jesseduffield/lazygit"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

for cmd in curl jq tar; do
  if ! need_cmd "$cmd"; then
    echo "ERROR: need $cmd" >&2
    exit 1
  fi
done

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if need_cmd sudo; then
    SUDO="sudo"
  else
    echo "ERROR: need root or sudo" >&2
    exit 1
  fi
fi

latest_tag() {
  gr_latest_tag "$REPO"
}

arch_suffix() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "linux_x86_64" ;;
    aarch64 | arm64) echo "linux_arm64" ;;
    armv6l | armv7l) echo "linux_armv6" ;;
    i686 | i386) echo "linux_32-bit" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

tag="$(latest_tag || true)"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest lazygit release tag" >&2
  exit 1
fi

if gr_bin_has_tag "$BIN_PATH" "$tag"; then
  echo "Already current: $BIN_PATH ($tag)"
  echo "Done."
  echo "lazygit path: $(command -v lazygit || true)"
  lazygit --version 2>&1 | head -n 1 || true
  exit 0
fi

version="${tag#v}"
suffix="$(arch_suffix)"
asset="lazygit_${version}_${suffix}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT

tarball="${tmpdir}/${asset}"

if ! gr_download "$url" "$tarball"; then
  gr_exit_if_keeping "$BIN_PATH" "GitHub download failed"
  echo "ERROR: download failed: $url" >&2
  exit 1
fi

extract_dir="${tmpdir}/extract"
mkdir -p "$extract_dir"
tar -xzf "$tarball" -C "$extract_dir"

binary="$(find "$extract_dir" -type f -name lazygit -print -quit)"
if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
  echo "ERROR: lazygit binary not found in archive" >&2
  exit 1
fi

echo "Installing $BIN_PATH"
gr_install_binary "$binary" "$BIN_PATH" "$SUDO"

echo "Done."
echo "lazygit path: $(command -v lazygit || true)"
lazygit --version 2>&1 | head -n 1 || true
