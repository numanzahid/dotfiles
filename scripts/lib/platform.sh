#!/usr/bin/env bash
# OS / glibc helpers shared by dotfiles install scripts (Debian + Ubuntu).

df_version_ge() {
  printf '%s\n%s\n' "$2" "$1" | sort -C -V
}

df_host_glibc_version() {
  local ver
  ver="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
  [[ -n "$ver" ]] || ver="$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)"
  [[ -n "$ver" ]] || return 1
  printf '%s' "$ver"
}

df_host_os_id() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    printf '%s' "${ID:-unknown}"
    return 0
  fi
  printf '%s' "unknown"
}

df_prepend_local_bin() {
  local local_bin="${HOME}/.local/bin"
  case ":${PATH}:" in
    *":${local_bin}:"*) ;;
    *) export PATH="${local_bin}:${PATH}" ;;
  esac
}

df_tree_sitter_cli_runs() {
  local bin="$1"
  [[ -n "$bin" && -x "$bin" ]] && "$bin" --version &>/dev/null
}

df_tree_sitter_cli_version() {
  local bin="$1"
  if ! df_tree_sitter_cli_runs "$bin"; then
    return 1
  fi
  "$bin" --version 2>/dev/null | awk '{print $2}'
}

# Newest CLI we can use on this host (prebuilt limits on older glibc).
df_tree_sitter_expected_cli_version() {
  local glibc="${1:-$(df_host_glibc_version)}"
  if df_version_ge "$glibc" "2.39"; then
    printf '%s' "0.26.11"
  elif df_version_ge "$glibc" "2.34"; then
    printf '%s' "0.25.6"
  elif df_version_ge "$glibc" "2.29"; then
    printf '%s' "0.24.7"
  else
    return 1
  fi
}

# Minimum CLI version install scripts treat as success (matches what we can install).
df_tree_sitter_install_min_version() {
  local glibc="${1:-$(df_host_glibc_version)}"
  if df_version_ge "$glibc" "2.39"; then
    printf '%s' "0.26.1"
  elif df_version_ge "$glibc" "2.34"; then
    printf '%s' "0.25.0"
  else
    printf '%s' "0.24.0"
  fi
}

df_tree_sitter_cli_ok_for_host() {
  local bin="$1"
  local glibc min_ver ver
  glibc="$(df_host_glibc_version)" || return 1
  min_ver="$(df_tree_sitter_install_min_version "$glibc")"
  ver="$(df_tree_sitter_cli_version "$bin")" || return 1
  df_version_ge "$ver" "$min_ver"
}
