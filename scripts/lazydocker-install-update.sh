#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade lazydocker from official GitHub releases:
#   https://github.com/jesseduffield/lazydocker
#
# Installs to /usr/local/bin/lazydocker
# Re-run anytime to upgrade.
# Not part of ./install.sh or ./install-tools.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/lazydocker-install-update.sh

Install or upgrade lazydocker from GitHub releases.
https://github.com/jesseduffield/lazydocker

Installs /usr/local/bin/lazydocker. Needs curl, jq, tar, sudo.
Optional. Not part of ./install.sh --all or ./install-tools.sh.

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

REPO="jesseduffield/lazydocker"
BIN_PATH="/usr/local/bin/lazydocker"

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
    x86_64 | amd64) echo "Linux_x86_64" ;;
    aarch64 | arm64) echo "Linux_arm64" ;;
    armv7l) echo "Linux_armv7" ;;
    armv6l) echo "Linux_armv6" ;;
    i686 | i386) echo "Linux_x86" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

tag="$(latest_tag || true)"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  gr_exit_if_keeping "$BIN_PATH" "could not resolve latest ${REPO} tag"
  echo "ERROR: could not resolve latest lazydocker release tag" >&2
  exit 1
fi

if gr_bin_has_tag "$BIN_PATH" "$tag"; then
  echo "Already current: $BIN_PATH ($tag)"
  echo "Done."
  echo "lazydocker path: $(command -v lazydocker || true)"
  lazydocker --version 2>&1 | head -n 1 || true
  exit 0
fi

version="${tag#v}"
suffix="$(arch_suffix)"
asset="lazydocker_${version}_${suffix}.tar.gz"
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

binary="$(find "$extract_dir" -type f -name lazydocker -print -quit)"
if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
  echo "ERROR: lazydocker binary not found in archive" >&2
  exit 1
fi

echo "Installing $BIN_PATH"
$SUDO install -m 755 "$binary" "$BIN_PATH"

echo "Done."
echo "lazydocker path: $(command -v lazydocker || true)"
lazydocker --version 2>&1 | head -n 1 || true
