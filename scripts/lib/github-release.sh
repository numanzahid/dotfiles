#!/usr/bin/env bash
# Shared helpers for GitHub release binary installs.
set -euo pipefail

gr_need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

gr_require_cmds() {
  local cmd
  for cmd in "$@"; do
    if ! gr_need_cmd "$cmd"; then
      echo "ERROR: need $cmd" >&2
      exit 1
    fi
  done
}

gr_sudo() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    if gr_need_cmd sudo; then
      echo sudo
    else
      echo "ERROR: need root or sudo" >&2
      exit 1
    fi
  fi
}

gr_latest_tag() {
  local repo="$1"
  curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r .tag_name
}

gr_download() {
  local url="$1"
  local dest="$2"
  echo "Downloading: $url"
  curl -fL --retry 3 --retry-delay 1 -o "$dest" "$url"
}

gr_find_binary() {
  local dir="$1"
  local name="$2"
  find "$dir" -type f -name "$name" -print -quit
}

# Safe under set -o pipefail (plain "cmd --version | head" can exit 141).
gr_print_version_line() {
  local cmd="$1"
  shift
  "$cmd" --version "$@" 2>&1 | head -n 1 || true
}

gr_install_binary() {
  local binary="$1"
  local dest="$2"
  local sudo_cmd="$3"
  echo "Installing $dest"
  $sudo_cmd install -m 755 "$binary" "$dest"
}

gr_arch_gnu() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "x86_64-unknown-linux-gnu" ;;
    aarch64 | arm64) echo "aarch64-unknown-linux-gnu" ;;
    armv7l | armv6l) echo "arm-unknown-linux-gnueabihf" ;;
    i686 | i386) echo "i686-unknown-linux-gnu" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

gr_arch_musl() {
  case "$(uname -m)" in
    x86_64 | amd64) echo "x86_64-unknown-linux-musl" ;;
    aarch64 | arm64) echo "aarch64-unknown-linux-musl" ;;
    armv7l | armv6l) echo "armv7-unknown-linux-musleabihf" ;;
    i686 | i386) echo "i686-unknown-linux-musl" ;;
    *)
      echo "ERROR: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac
}

gr_install_from_targz() {
  local url="$1"
  local bin_name="$2"
  local dest_path="$3"

  local sudo_cmd tmpdir tarball extract_dir binary
  sudo_cmd="$(gr_sudo)"
  tmpdir="$(mktemp -d)"
  tarball="${tmpdir}/archive.tar.gz"
  extract_dir="${tmpdir}/extract"

  trap "rm -rf '${tmpdir}'" EXIT

  gr_download "$url" "$tarball"
  mkdir -p "$extract_dir"
  tar -xzf "$tarball" -C "$extract_dir"

  binary="$(gr_find_binary "$extract_dir" "$bin_name")"
  if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
    echo "ERROR: $bin_name binary not found in archive" >&2
    exit 1
  fi

  gr_install_binary "$binary" "$dest_path" "$sudo_cmd"
}
