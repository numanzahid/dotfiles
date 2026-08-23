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

# Shared curl flags so a GitHub blip does not abort install.sh --all.
# curl --retry covers timeouts and HTTP 408/429/5xx. It does not retry TLS
# reset (35) or recv failures. Do not use --retry-all-errors: that also
# retries HTTP 404 and makes missing-asset fallbacks very slow.
GR_CURL_HAS_RETRY_CONNREFUSED=""
gr_curl() {
  local -a args
  local attempt=1
  local max=4
  local delay=5
  local rc

  args=(
    --connect-timeout 20
    --retry 6
    --retry-delay 5
    --retry-max-time 120
  )
  if [[ -z "$GR_CURL_HAS_RETRY_CONNREFUSED" ]]; then
    GR_CURL_HAS_RETRY_CONNREFUSED=0
    # curl 8.x lists this under --help all, not the short --help.
    if { curl --help all 2>/dev/null || curl --help 2>/dev/null; } | grep -q -- '--retry-connrefused'; then
      GR_CURL_HAS_RETRY_CONNREFUSED=1
    fi
  fi
  if [[ "$GR_CURL_HAS_RETRY_CONNREFUSED" -eq 1 ]]; then
    args+=(--retry-connrefused)
  fi

  while true; do
    curl "${args[@]}" "$@" && return 0
    rc=$?
    case "$rc" in
      0) return 0 ;;
      7 | 35 | 52 | 55 | 56) ;;
      *) return "$rc" ;;
    esac
    if ((attempt >= max)); then
      return "$rc"
    fi
    echo "WARNING: curl exit ${rc}; retry ${attempt}/${max} in ${delay}s" >&2
    sleep "$delay"
    attempt=$((attempt + 1))
    delay=$((delay * 2))
  done
}

gr_wget() {
  wget --timeout=20 --tries=8 --waitretry=5 --retry-connrefused "$@"
}

gr_latest_tag() {
  local repo="$1"
  gr_curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" | jq -r .tag_name
}

gr_download() {
  local url="$1"
  local dest="$2"
  echo "Downloading: $url"
  gr_curl -fL -o "$dest" "$url"
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
