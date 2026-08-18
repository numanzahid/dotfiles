#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade GitHub CLI (gh) from official GitHub releases.
# https://github.com/cli/cli
#
# Re-run anytime to upgrade.

REPO="cli/cli"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

for cmd in curl jq; do
  if ! need_cmd "$cmd"; then
    echo "ERROR: need $cmd" >&2
    exit 1
  fi
done

if ! need_cmd apt-get; then
  echo "ERROR: need apt-get to install the .deb package" >&2
  exit 1
fi

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

deb_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "amd64" ;;
    aarch64 | arm64) echo "arm64" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

tag="$(latest_tag)"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  echo "ERROR: could not resolve latest gh release tag" >&2
  exit 1
fi

version="${tag#v}"
arch="$(deb_arch)"
asset="gh_${version}_linux_${arch}.deb"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT

deb="${tmpdir}/${asset}"

echo "Downloading: $url"
curl -fL --retry 3 --retry-delay 1 -o "$deb" "$url"

echo "Installing: $asset"
$SUDO apt-get install -y "$deb"

echo "Done."
echo "gh path: $(command -v gh || true)"
gh --version 2>&1 | head -n 1 || true
