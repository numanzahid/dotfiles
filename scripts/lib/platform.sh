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

df_nvim_treesitter_cli_min() {
  printf '%s' "0.26.1"
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

# Install success: binary exists and executes.
df_tree_sitter_cli_ok_for_host() {
  df_tree_sitter_cli_runs "$1"
}

# nvim-treesitter :checkhealth minimum (may be unreachable on older glibc hosts).
df_tree_sitter_cli_meets_nvim_treesitter_min() {
  local bin="$1" ver min
  min="$(df_nvim_treesitter_cli_min)"
  ver="$(df_tree_sitter_cli_version "$bin")" || return 1
  df_version_ge "$ver" "$min"
}

df_tree_sitter_cli_degraded() {
  df_tree_sitter_cli_ok_for_host "$1" && ! df_tree_sitter_cli_meets_nvim_treesitter_min "$1"
}
