#!/usr/bin/env bash
# Shared helpers for GitHub release binary installs.
set -euo pipefail

GR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=journal.sh
if [[ -f "$GR_LIB_DIR/journal.sh" ]]; then
  source "$GR_LIB_DIR/journal.sh"
fi

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

gr_managed_paths_file() {
  printf '%s/dotfiles/managed-paths' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

gr_path_is_tracked() {
  local dest="$1"
  local file
  file="$(gr_managed_paths_file)"
  [[ -f "$file" ]] || return 1
  grep -Fxq -- "$dest" "$file"
}

gr_track_path() {
  local dest="$1"
  local file dir
  file="$(gr_managed_paths_file)"
  dir="$(dirname "$file")"
  if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
    return 0
  fi
  if gr_path_is_tracked "$dest"; then
    return 0
  fi
  mkdir -p "$dir"
  printf '%s\n' "$dest" >>"$file"
}

gr_sha256_file() {
  if gr_need_cmd sha256sum; then
    sha256sum "$1" | awk '{print $1}'
    return 0
  fi
  if gr_need_cmd shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
    return 0
  fi
  return 1
}

# SHA256 from a GitHub release asset digest or a SHA256SUMS/checksums file.
# Prints hex on stdout. Returns 1 if upstream has nothing we can use.
gr_github_asset_sha256() {
  local repo="$1"
  local tag="$2"
  local filename="$3"
  local json digest sums_url line hash
  local tmp=""

  gr_need_cmd jq || return 1

  json="$(gr_curl -fsSL "https://api.github.com/repos/${repo}/releases/tags/${tag}")" || return 1

  digest="$(printf '%s\n' "$json" | jq -r --arg n "$filename" '
    .assets[]? | select(.name == $n) | .digest // empty
  ')"
  if [[ "$digest" == sha256:* || "$digest" == SHA256:* ]]; then
    printf '%s\n' "${digest#*:}"
    return 0
  fi

  sums_url="$(printf '%s\n' "$json" | jq -r '
    [
      .assets[]?
      | select(.name | test("(?i)(sha256sums|sha256sum|checksums\\.txt|SHA256SUMS)"))
      | .browser_download_url
    ] | first // empty
  ')"
  [[ -n "$sums_url" && "$sums_url" != "null" ]] || return 1

  tmp="$(mktemp)"
  if ! gr_curl -fsSL -o "$tmp" "$sums_url"; then
    rm -f "$tmp"
    return 1
  fi
  line="$(grep -F -- "$filename" "$tmp" | head -n 1 || true)"
  rm -f "$tmp"
  [[ -n "$line" ]] || return 1
  hash="$(printf '%s\n' "$line" | awk '{print $1}')"
  [[ "$hash" =~ ^[0-9a-fA-F]{64}$ ]] || return 1
  printf '%s\n' "$hash"
}

# Verify when GitHub publishes a checksum. Mismatch aborts.
# No checksum: continue (TLS only). Does not invent hashes.
gr_verify_or_continue() {
  local file="$1"
  local url="$2"
  local repo tag filename expected actual

  if [[ ! "$url" =~ github\.com/([^/]+/[^/]+)/releases/download/([^/]+)/([^/?]+) ]]; then
    echo "No GitHub checksum lookup for this URL; continuing"
    return 0
  fi
  repo="${BASH_REMATCH[1]}"
  tag="${BASH_REMATCH[2]}"
  filename="${BASH_REMATCH[3]}"

  expected="$(gr_github_asset_sha256 "$repo" "$tag" "$filename" || true)"
  if [[ -z "$expected" ]]; then
    echo "No upstream SHA256 for ${filename}; continuing"
    return 0
  fi

  actual="$(gr_sha256_file "$file" || true)"
  if [[ -z "$actual" ]]; then
    echo "ERROR: cannot compute SHA256 (need sha256sum or shasum)" >&2
    exit 1
  fi
  if [[ "${actual,,}" != "${expected,,}" ]]; then
    echo "ERROR: SHA256 mismatch for ${filename}" >&2
    echo "  expected: ${expected}" >&2
    echo "  actual:   ${actual}" >&2
    exit 1
  fi
  echo "SHA256 ok: ${filename}"
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
  gr_curl -fL -o "$dest" "$url" || return 1
  gr_verify_or_continue "$dest" "$url"
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
  if declare -F df_journal_once >/dev/null 2>&1; then
    df_journal_once binary "$dest_path"
  fi
}
