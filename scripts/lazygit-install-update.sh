#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade lazygit from official GitHub releases:
#   https://github.com/jesseduffield/lazygit
#
# Installs to /usr/local/bin/lazygit
# Re-run anytime to upgrade.

REPO="jesseduffield/lazygit"
BIN_PATH="/usr/local/bin/lazygit"

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
  curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r .tag_name
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

tag="$(latest_tag)"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  echo "ERROR: could not resolve latest lazygit release tag" >&2
  exit 1
fi

version="${tag#v}"
suffix="$(arch_suffix)"
asset="lazygit_${version}_${suffix}.tar.gz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT

tarball="${tmpdir}/${asset}"

echo "Downloading: $url"
if need_cmd curl; then
  curl -fL --retry 3 --retry-delay 1 -o "$tarball" "$url"
else
  wget -O "$tarball" "$url"
fi

extract_dir="${tmpdir}/extract"
mkdir -p "$extract_dir"
tar -xzf "$tarball" -C "$extract_dir"

binary="$(find "$extract_dir" -type f -name lazygit | head -n 1)"
if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
  echo "ERROR: lazygit binary not found in archive" >&2
  exit 1
fi

echo "Installing $BIN_PATH"
$SUDO install -m 755 "$binary" "$BIN_PATH"

echo "Done."
echo "lazygit path: $(command -v lazygit || true)"
lazygit --version | head -n 1
