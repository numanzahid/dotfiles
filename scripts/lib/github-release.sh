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

# GitHub often RSTs IPv6 and/or HTTP/2 (curl 35 at 0 bytes). Apt still works
# because it does not use github.com. Prefer IPv4 + HTTP/1.1, then fall back.
# Override: DOTFILES_CURL_MODE=auto|ipv4|default
GR_CURL_HAS_RETRY_CONNREFUSED=""
gr_curl() {
  local -a retry_flags extra modes
  local mode attempt rc

  retry_flags=(
    --connect-timeout 15
    --retry 2
    --retry-delay 2
    --retry-max-time 45
  )
  if [[ -z "$GR_CURL_HAS_RETRY_CONNREFUSED" ]]; then
    GR_CURL_HAS_RETRY_CONNREFUSED=0
    # curl 8.x lists this under --help all, not the short --help.
    if { curl --help all 2>/dev/null || curl --help 2>/dev/null; } | grep -q -- '--retry-connrefused'; then
      GR_CURL_HAS_RETRY_CONNREFUSED=1
    fi
  fi
  if [[ "$GR_CURL_HAS_RETRY_CONNREFUSED" -eq 1 ]]; then
    retry_flags+=(--retry-connrefused)
  fi

  case "${DOTFILES_CURL_MODE:-auto}" in
    ipv4) modes=("ipv4") ;;
    default) modes=("default") ;;
    *) modes=("ipv4" "http11" "default") ;;
  esac

  rc=1
  for mode in "${modes[@]}"; do
    extra=()
    case "$mode" in
      ipv4) extra=(-4 --http1.1) ;;
      http11) extra=(--http1.1) ;;
    esac
    for attempt in 1 2; do
      curl "${retry_flags[@]}" "${extra[@]}" "$@" && return 0
      rc=$?
      case "$rc" in
        7 | 28 | 35 | 52 | 55 | 56) ;;
        *) return "$rc" ;;
      esac
      echo "WARNING: curl ${mode} exit ${rc}; retry ${attempt}/2" >&2
      sleep 2
    done
  done
  return "$rc"
}

gr_wget() {
  wget -4 --timeout=20 --tries=8 --waitretry=5 --retry-connrefused "$@"
}

gr_git() {
  git -c http.version=HTTP/1.1 "$@"
}

gr_bin_has_tag() {
  local dest="$1"
  local tag="$2"
  local ver="${tag#v}"
  [[ -n "$ver" && -x "$dest" ]] || return 1
  "$dest" --version 2>&1 | grep -F -q "$ver"
}

gr_keep_existing() {
  local dest="$1"
  local why="$2"
  if [[ -x "$dest" ]]; then
    echo "WARN: ${why}; keeping existing $dest" >&2
    return 0
  fi
  return 1
}

gr_exit_if_keeping() {
  local dest="$1"
  local why="$2"
  local bin
  bin="$(basename "$dest")"
  gr_keep_existing "$dest" "$why" || return 1
  echo "Done."
  echo "$bin path: $(command -v "$bin" || true)"
  gr_print_version_line "$bin"
  exit 0
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
  local tag="${4:-}"

  local sudo_cmd tmpdir tarball extract_dir binary
  if [[ -n "$tag" ]] && gr_bin_has_tag "$dest_path" "$tag"; then
    echo "Already current: $dest_path ($tag)"
    return 0
  fi

  sudo_cmd="$(gr_sudo)"
  tmpdir="$(mktemp -d)"
  tarball="${tmpdir}/archive.tar.gz"
  extract_dir="${tmpdir}/extract"

  trap "rm -rf '${tmpdir}'" EXIT

  if ! gr_download "$url" "$tarball"; then
    if gr_keep_existing "$dest_path" "GitHub download failed"; then
      return 0
    fi
    echo "ERROR: download failed: $url" >&2
    exit 1
  fi
  mkdir -p "$extract_dir"
  tar -xzf "$tarball" -C "$extract_dir"

  binary="$(gr_find_binary "$extract_dir" "$bin_name")"
  if [[ -z "${binary:-}" || ! -f "$binary" ]]; then
    echo "ERROR: $bin_name binary not found in archive" >&2
    exit 1
  fi

  gr_install_binary "$binary" "$dest_path" "$sudo_cmd"
}
