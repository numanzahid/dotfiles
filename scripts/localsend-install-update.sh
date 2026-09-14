#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade official LocalSend CLI from GitHub releases.
# https://github.com/localsend/localsend
#
# Sends files and folders to phones/desktops on the LAN. Optional; not part of
# ./devbox.sh --all or ./server.sh --all.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/localsend-cli"
REPO="localsend/localsend"

usage() {
  cat <<'EOF'
Usage: ./scripts/localsend-install-update.sh [options]

Install or upgrade the official LocalSend CLI from GitHub releases.
https://github.com/localsend/localsend

Installs /usr/local/bin/localsend-cli. Needs curl, jq, tar, sudo.
Optional. Not part of ./devbox.sh --all or ./server.sh --all.

Examples (phone must run the LocalSend app on the same LAN):
  localsend-cli send --to "Phone Name" report.pdf
  localsend-cli send --to 192.168.1.50 ./folder
  localsend-cli send file.zip          # interactive device picker (needs TTY)

Firewall (if needed): allow TCP and UDP 53317.

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

uninstall_localsend() {
  df_inst_remove_github_binary localsend-cli "$BIN_PATH"
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall localsend-cli uninstall_localsend; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

gr_require_cmds curl jq tar

localsend_linux_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "linux-x86-64" ;;
    aarch64 | arm64) echo "linux-arm-64" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m) (need x86_64 or arm64)" >&2
      exit 1
      ;;
  esac
}

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest LocalSend release tag" >&2
  exit 1
}

if gr_bin_has_tag "$BIN_PATH" "$tag"; then
  echo "Already current: $BIN_PATH ($tag)"
  echo "localsend-cli path: $(command -v localsend-cli || true)"
  gr_print_version_line localsend-cli
  exit 0
fi

version="${tag#v}"
arch="$(localsend_linux_arch)"
asset="LocalSend-CLI-${version}-${arch}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

sudo_cmd="$(gr_sudo)"
tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT
tarball="${tmpdir}/${asset}"
extract_dir="${tmpdir}/extract"

if ! gr_download "$url" "$tarball"; then
  gr_exit_if_keeping "$BIN_PATH" "GitHub download failed"
  echo "ERROR: download failed: $url" >&2
  echo "ERROR: LocalSend CLI may be missing from this release (need v1.18+)." >&2
  exit 1
fi

mkdir -p "$extract_dir"
tar -xzf "$tarball" -C "$extract_dir"

binary="$(gr_find_binary "$extract_dir" localsend-cli || true)"
if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
  echo "ERROR: localsend-cli binary not found in archive" >&2
  exit 1
fi
if ! gr_file_is_elf "$binary"; then
  echo "ERROR: refusing to install non-ELF $binary as $BIN_PATH" >&2
  exit 1
fi

gr_install_binary "$binary" "$BIN_PATH" "$sudo_cmd"

echo "Done."
echo "localsend-cli path: $(command -v localsend-cli || true)"
gr_print_version_line localsend-cli
echo
echo "Send to phone: localsend-cli send --to \"Phone Name\" /path/to/file"
echo "Or by IP:      localsend-cli send --to 192.168.1.50 /path/to/folder"
