#!/usr/bin/env bash
set -euo pipefail

# Install or upgrade chafa from official source release (build from tarball).
# https://github.com/hpjansson/chafa
#
# Re-run anytime to upgrade.

REPO="hpjansson/chafa"
PREFIX="/usr/local"

need_cmd() { command -v "$1" >/dev/null 2>&1; }

gr_require_cmds() {
  local cmd
  for cmd in "$@"; do
    if ! need_cmd "$cmd"; then
      echo "ERROR: need $cmd" >&2
      exit 1
    fi
  done
}

gr_require_cmds curl jq tar xz

SUDO=""
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  if need_cmd sudo; then
    SUDO="sudo"
  else
    echo "ERROR: need root or sudo" >&2
    exit 1
  fi
fi

remove_apt_chafa() {
  if ! command -v apt-get >/dev/null 2>&1; then
    return 0
  fi

  local pkgs=()
  local pkg
  for pkg in chafa libchafa0 libchafa-dev; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      pkgs+=("$pkg")
    fi
  done

  if ((${#pkgs[@]} > 0)); then
    echo "Removing apt chafa packages to avoid library conflicts: ${pkgs[*]}"
    $SUDO apt-get remove -y "${pkgs[@]}"
  fi
}

install_build_deps() {
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "ERROR: chafa build requires apt-based build dependencies on this script" >&2
    exit 1
  fi

  local deps=(
    build-essential
    pkg-config
    libglib2.0-dev
    libgdk-pixbuf-2.0-dev
    libjpeg-dev
    libpng-dev
    librsvg2-dev
    libtiff-dev
    libwebp-dev
  )

  echo "Installing chafa build dependencies (apt)..."
  $SUDO apt-get update
  $SUDO apt-get install -y "${deps[@]}"
}

verify_chafa() {
  local bin="$1"
  if [[ ! -x "$bin" ]]; then
    echo "ERROR: chafa binary not found at $bin" >&2
    return 1
  fi

  if ! "$bin" --version >/dev/null 2>&1; then
    echo "ERROR: chafa failed to run. Library mismatch?" >&2
    echo "Try: sudo ldconfig" >&2
    ldd "$bin" 2>/dev/null || true
    return 1
  fi
}

tag="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" | jq -r .tag_name)"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  echo "ERROR: could not resolve latest chafa release tag" >&2
  exit 1
fi

version="${tag#v}"
asset="chafa-${version}.tar.xz"
url="https://github.com/${REPO}/releases/download/${tag}/${asset}"

remove_apt_chafa

if ! need_cmd make || ! pkg-config --exists glib-2.0 2>/dev/null; then
  install_build_deps
fi

gr_require_cmds make

tmpdir="$(mktemp -d)"
trap "rm -rf '${tmpdir}'" EXIT

archive="${tmpdir}/${asset}"
srcdir="${tmpdir}/chafa-${version}"

echo "Downloading: $url"
curl -fL --retry 3 --retry-delay 1 -o "$archive" "$url"
tar -xJf "$archive" -C "$tmpdir"

if [[ ! -f "${srcdir}/configure" ]]; then
  echo "ERROR: expected autotools release with configure in ${srcdir}" >&2
  exit 1
fi

echo "Building chafa ${version}..."
(
  cd "$srcdir"
  ./configure --prefix="$PREFIX" --enable-rpath
  make -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)"
)

echo "Installing chafa to ${PREFIX}"
(
  cd "$srcdir"
  $SUDO make install
)

echo "Refreshing linker cache..."
$SUDO ldconfig

chafa_bin="$(command -v chafa || true)"
verify_chafa "${chafa_bin:-$PREFIX/bin/chafa}"

echo "Done."
echo "chafa path: $chafa_bin"
chafa --version | head -n 1
