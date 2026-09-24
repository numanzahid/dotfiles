#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade official LocalSend CLI from GitHub releases.
# https://github.com/localsend/localsend
#
# Linux x86_64/arm64 (Fedora, Debian, Arch). Optional; not part of --all.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/localsend-cli"
REPO="localsend/localsend"

usage() {
  cat <<'EOF'
Usage: ./scripts/localsend-install-update.sh [options]

Install or upgrade the official LocalSend CLI from GitHub releases.
https://github.com/localsend/localsend

Installs /usr/local/bin/localsend-cli. Needs curl, jq, tar, sudo.
Works on Fedora, Debian/Ubuntu, and Arch (x86_64 and arm64).
Optional. Not part of ./desktop.sh, ./devbox.sh, or ./server.sh --all.

Current release CLI (v1.18.x): use -f/--file (files only), then pick the phone
in the terminal UI. Folders: tar/zip first, or upgrade when send supports dirs.

Examples (phone must run the LocalSend app on the same LAN):
  localsend-cli -f report.pdf
  localsend-cli -f file1.zip -f file2.zip
  tar czf /tmp/folder.tar.gz mydir && localsend-cli -f /tmp/folder.tar.gz

Needs a TTY for the device picker (local terminal or: ssh -t host ...).

Firewall (if transfers fail): allow TCP and UDP 53317.

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
  local raw
  raw="$(gr_arch_raw)" || exit 1
  case "$raw" in
    amd64) echo "linux-x86-64" ;;
    arm64) echo "linux-arm-64" ;;
    *)
      echo "ERROR: localsend has no release for this architecture: $(uname -m) (need x86_64 or arm64)" >&2
      exit 1
      ;;
  esac
}

localsend_asset_name() {
  local tag="$1"
  local version="${tag#v}"
  local arch
  arch="$(localsend_linux_arch)"
  printf 'LocalSend-CLI-%s-%s.tar.gz' "$version" "$arch"
}

localsend_release_has_asset() {
  local tag="$1"
  local asset="$2"
  gr_curl -fsSL "https://api.github.com/repos/${REPO}/releases/tags/${tag}" |
    jq -e --arg name "$asset" '.assets[] | select(.name == $name) | .name' >/dev/null
}

print_firewall_hint() {
  if command -v firewall-cmd >/dev/null 2>&1 &&
    systemctl is-active firewalld.service >/dev/null 2>&1; then
    echo "Fedora firewalld is active. If LAN send fails, allow mDNS port:"
    echo "  sudo firewall-cmd --permanent --add-port=53317/tcp"
    echo "  sudo firewall-cmd --permanent --add-port=53317/udp"
    echo "  sudo firewall-cmd --reload"
    return 0
  fi
  if command -v ufw >/dev/null 2>&1 &&
    ufw status 2>/dev/null | grep -qi 'Status: active'; then
    echo "ufw is active. If LAN send fails:"
    echo "  sudo ufw allow 53317/tcp"
    echo "  sudo ufw allow 53317/udp"
  fi
}

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest LocalSend release tag" >&2
  exit 1
}

asset="$(localsend_asset_name "$tag")"
if ! localsend_release_has_asset "$tag" "$asset"; then
  gr_exit_if_keeping "$BIN_PATH" "release ${tag} has no ${asset}"
  echo "ERROR: ${asset} not found in GitHub release ${tag}" >&2
  echo "ERROR: need LocalSend v1.18+ with CLI assets for this CPU." >&2
  exit 1
fi

if gr_bin_has_tag "$BIN_PATH" "$tag"; then
  echo "Already current: $BIN_PATH ($tag)"
  echo "localsend-cli path: $(command -v localsend-cli || true)"
  gr_print_version_line localsend-cli
  print_firewall_hint
  exit 0
fi

url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

sudo_cmd="$(gr_sudo)"
tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT
tarball="${tmpdir}/${asset}"
extract_dir="${tmpdir}/extract"

if ! gr_download "$url" "$tarball"; then
  gr_exit_if_keeping "$BIN_PATH" "GitHub download failed"
  echo "ERROR: download failed: $url" >&2
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

if ! localsend-cli --version >/dev/null 2>&1; then
  echo "ERROR: installed binary failed: localsend-cli --version" >&2
  exit 1
fi

echo "Done."
echo "localsend-cli path: $(command -v localsend-cli || true)"
gr_print_version_line localsend-cli
echo
echo "Send a file:   localsend-cli -f /path/to/file"
echo "Send archive:  tar czf /tmp/dir.tar.gz mydir && localsend-cli -f /tmp/dir.tar.gz"
echo
print_firewall_hint
