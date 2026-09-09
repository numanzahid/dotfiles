#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade gdu from GitHub releases.
# https://github.com/dundee/gdu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_PATH="/usr/local/bin/gdu"

usage() {
  cat <<'EOF'
Usage: ./scripts/gdu-install-update.sh [options]

Install or upgrade gdu from GitHub releases (disk usage analyzer).
https://github.com/dundee/gdu

Installs /usr/local/bin/gdu. Needs curl, jq, tar, sudo.
Invoked by ./devbox.sh, ./desktop.sh, and ./server.sh --all.

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

uninstall_gdu() {
  df_inst_remove_github_binary gdu "$BIN_PATH"
}

_df_entry=0
df_install_cli_entry "$@" || _df_entry=$?
case "$_df_entry" in
  1) df_inst_run_uninstall gdu uninstall_gdu; exit 0 ;;
  2) usage; exit 0 ;;
  3) usage >&2; exit 1 ;;
esac

# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/github-release.sh"

REPO="dundee/gdu"

gr_require_cmds curl jq tar

gdu_linux_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "linux_amd64" ;;
    aarch64 | arm64) echo "linux_arm64" ;;
    armv7l) echo "linux_armv7l" ;;
    armv6l) echo "linux_armv6l" ;;
    armv5l) echo "linux_armv5l" ;;
    arm | armv4l) echo "linux_arm" ;;
    i686 | i386) echo "linux_386" ;;
    mips) echo "linux_mips" ;;
    mips64) echo "linux_mips64" ;;
    mips64le) echo "linux_mips64le" ;;
    mipsle) echo "linux_mipsle" ;;
    ppc64le) echo "linux_ppc64le" ;;
    riscv64) echo "linux_riscv64" ;;
    s390x) echo "linux_s390x" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

tag="$(gr_latest_tag "$REPO" || true)"
[[ -n "$tag" && "$tag" != "null" ]] || {
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest gdu release tag" >&2
  exit 1
}

if gr_bin_has_tag "$BIN_PATH" "$tag"; then
  echo "Already current: $BIN_PATH ($tag)"
  echo "gdu path: $(command -v gdu || true)"
  gr_print_version_line gdu
  exit 0
fi

arch="$(gdu_linux_arch)"
asset="gdu_${arch}.tgz"
member="gdu_${arch}"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

sudo_cmd="$(gr_sudo)"
tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT
tarball="${tmpdir}/${asset}"
binary="${tmpdir}/${member}"

if ! gr_download "$url" "$tarball"; then
  gr_exit_if_keeping "$BIN_PATH" "GitHub download failed"
  echo "ERROR: download failed: $url" >&2
  exit 1
fi

tar -xzf "$tarball" -C "$tmpdir"
if [[ ! -f "$binary" ]]; then
  echo "ERROR: expected binary missing in archive: $member" >&2
  exit 1
fi
if ! gr_file_is_elf "$binary"; then
  echo "ERROR: refusing to install non-ELF $binary as $BIN_PATH" >&2
  exit 1
fi

gr_install_binary "$binary" "$BIN_PATH" "$sudo_cmd"

echo "Done."
echo "gdu path: $(command -v gdu || true)"
gr_print_version_line gdu
