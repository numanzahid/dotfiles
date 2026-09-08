#!/usr/bin/env bash
# Shared uninstall helpers for *-install-update.sh scripts.
# Source from install scripts; do not run directly.

: "${TARGET_HOME:=${HOME:?}}"
: "${SCRIPTS_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if ! declare -F df_journal_remove_path >/dev/null 2>&1; then
  # shellcheck source=journal.sh
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/journal.sh"
fi
if ! declare -F df_run_privileged >/dev/null 2>&1; then
  # shellcheck source=privilege.sh
  source "$SCRIPTS_DIR/lib/privilege.sh"
fi
if ! declare -F df_component_forget >/dev/null 2>&1; then
  # shellcheck source=component-state.sh
  source "$SCRIPTS_DIR/lib/component-state.sh"
fi

df_inst_log() {
  printf '[uninstall] %s\n' "$*"
}

df_inst_die() {
  printf '[uninstall] ERROR: %s\n' "$*" >&2
  exit 1
}

df_inst_is_home_path() {
  local p="$1"
  [[ "$p" == "$TARGET_HOME" || "$p" == "$TARGET_HOME"/* ]]
}

df_inst_dry() {
  [[ "${DF_INSTALL_DRY_RUN:-${DRY_RUN:-0}}" -eq 1 ]]
}

df_inst_run() {
  if df_inst_dry; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

df_inst_confirm() {
  local name="$1"

  if df_inst_dry || [[ "${DF_INSTALL_YES:-0}" -eq 1 ]]; then
    return 0
  fi
  read -r -p "Uninstall dotfiles $name and all files it created? [y/N] " reply
  case "${reply:-N}" in
    y | Y | yes | YES) ;;
    *) df_inst_die "aborted" ;;
  esac
}

df_inst_forget_component() {
  local component="$1"

  if df_inst_dry; then
    df_inst_log "would forget component state: $component"
    return 0
  fi
  df_component_forget "$component"
}

df_inst_remove_path() {
  local dest="$1"

  [[ -n "$dest" ]] || return 0
  [[ -e "$dest" || -L "$dest" ]] || {
    df_journal_remove_path "$dest"
    return 0
  }
  if [[ "$dest" == "$TARGET_HOME" || "$dest" == "/" ]]; then
    df_inst_die "refusing to remove: $dest"
  fi

  if df_inst_dry; then
    df_inst_log "would remove $dest"
    return 0
  fi

  df_inst_log "remove $dest"
  if df_inst_is_home_path "$dest"; then
    if command -v trash-put >/dev/null 2>&1; then
      trash-put "$dest"
    elif [[ -d "$dest" && ! -L "$dest" ]]; then
      rm -rf "$dest"
    else
      rm -f "$dest"
    fi
  else
    if [[ -d "$dest" && ! -L "$dest" ]]; then
      df_run_privileged rm -rf "$dest"
    else
      df_run_privileged rm -f "$dest"
    fi
  fi
  df_journal_remove_path "$dest"
}

df_inst_remove_paths() {
  local p
  for p in "$@"; do
    df_inst_remove_path "$p"
  done
}

df_inst_remove_package() {
  local pkg="$1"

  [[ -n "$pkg" ]] || return 0
  if ! df_journal_has package-new "$pkg"; then
    df_inst_log "skip package $pkg (not recorded as installed by dotfiles)"
    return 0
  fi
  if ! df_pkg_is_installed "$pkg"; then
    df_inst_log "package already gone: $pkg"
    df_journal_remove_kind_path package-new "$pkg"
    return 0
  fi

  if df_inst_dry; then
    df_inst_log "would remove package: $pkg"
    return 0
  fi

  df_inst_log "remove package: $pkg"
  if command -v apt-get >/dev/null 2>&1; then
    df_run_privileged apt-get remove -y "$pkg"
  elif command -v dnf >/dev/null 2>&1; then
    df_run_privileged dnf remove -y "$pkg"
  else
    df_inst_log "WARN: cannot remove package $pkg (no apt/dnf)"
    return 0
  fi
  df_journal_remove_kind_path package-new "$pkg"
}

df_inst_remove_github_binary() {
  local name="$1"
  local bin_path="${2:-/usr/local/bin/$name}"

  df_inst_remove_path "$bin_path"
  df_inst_remove_path "$TARGET_HOME/.local/bin/$name"
}

df_inst_remove_journaled_git_clone() {
  local want="$1"
  local p

  while IFS= read -r p; do
    [[ -n "$p" ]] || continue
    if [[ -n "$want" && "$p" != "$want" ]]; then
      continue
    fi
    df_inst_remove_path "$p"
  done < <(df_journal_paths_for_kind git-clone)

  if [[ -n "$want" ]]; then
    df_inst_remove_path "$want"
  fi
}

df_inst_remove_neovim_install() {
  local p kind

  for kind in binary symlink opt-tree; do
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      case "$p" in
        /opt/nvim | /opt/nvim-* | /usr/local/bin/nvim)
          df_inst_remove_path "$p"
          ;;
      esac
    done < <(df_journal_paths_for_kind "$kind")
  done

  shopt -s nullglob
  for p in /opt/nvim /opt/nvim-*; do
    [[ -e "$p" || -L "$p" ]] || continue
    df_inst_remove_path "$p"
  done
  shopt -u nullglob

  df_inst_remove_path /usr/local/bin/nvim
  df_inst_remove_package neovim

  if [[ -f "${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/dotfiles/managed-paths" ]]; then
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      case "$p" in
        /opt/nvim | /opt/nvim-*)
          df_inst_untrack_managed_path "$p"
          ;;
      esac
    done <"${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/dotfiles/managed-paths"
  fi
}

df_inst_remove_tealdeer_data() {
  local base="${XDG_CACHE_HOME:-$TARGET_HOME/.cache}/tealdeer"
  local data="${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/tealdeer"
  local config="${XDG_CONFIG_HOME:-$TARGET_HOME/.config}/tealdeer"

  df_inst_remove_path "$base"
  df_inst_remove_path "$data"
  df_inst_remove_path "$config"
}

df_inst_remove_nerd_fonts() {
  local root="${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/fonts"
  local stamp="${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/dotfiles/cascadia-nerd-font.version"

  df_inst_untrack_managed_path "$root/dotfiles-caskaydia-cove"
  df_inst_untrack_managed_path "$root/dotfiles-jetbrains-mono"
  df_inst_untrack_managed_path "$stamp"
  df_inst_remove_path "$root/dotfiles-caskaydia-cove"
  df_inst_remove_path "$root/dotfiles-jetbrains-mono"
  df_inst_remove_path "$stamp"

  if ! df_inst_dry && command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f "$root" 2>/dev/null || true
  fi
}

df_inst_untrack_managed_path() {
  local path="$1"
  local file tmp

  [[ -n "$path" ]] || return 0
  file="${XDG_DATA_HOME:-$TARGET_HOME/.local/share}/dotfiles/managed-paths"
  [[ -f "$file" ]] || return 0
  if df_inst_dry; then
    return 0
  fi
  tmp="$(mktemp)"
  awk -v p="$path" '$0 != p { print }' "$file" >"$tmp"
  mv -f "$tmp" "$file"
}

df_inst_remove_fzf() {
  df_inst_remove_journaled_git_clone "$TARGET_HOME/.fzf"
  df_inst_remove_path "$TARGET_HOME/.fzf.bash"
  df_inst_remove_package fzf
}

df_inst_remove_tpm() {
  df_inst_remove_journaled_git_clone "$TARGET_HOME/.tmux/plugins/tpm"
  df_inst_remove_path "$TARGET_HOME/.tmux/plugins/tpm"
}

df_inst_remove_gh() {
  df_inst_remove_package gh
  df_inst_remove_path /usr/bin/gh
  df_inst_remove_path /usr/local/bin/gh
  df_inst_remove_gh_apt_repo
}

df_inst_remove_btop() {
  df_inst_remove_github_binary btop /usr/local/bin/btop
  df_inst_remove_package btop
}

df_inst_remove_fastfetch() {
  if declare -F df_remove_legacy_pfetch >/dev/null 2>&1; then
    run() { df_inst_run "$@"; }
    df_remove_legacy_pfetch
  fi
  df_inst_remove_github_binary fastfetch /usr/local/bin/fastfetch
  df_inst_remove_package fastfetch
}

df_inst_remove_deps_packages() {
  local pkg
  for pkg in \
    bash bash-completion ca-certificates curl git gzip jq less locales \
    ripgrep tar tmux trash-cli wget unzip fontconfig; do
    df_inst_remove_package "$pkg"
  done
}

df_inst_remove_gh_apt_repo() {
  local f

  if ! command -v apt-get >/dev/null 2>&1; then
    return 0
  fi

  if grep -rq 'cli\.github\.com' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    df_inst_log "remove GitHub CLI apt repo files"
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      if df_inst_dry; then
        df_inst_log "would remove $f"
      else
        df_run_privileged rm -f "$f"
      fi
    done < <(grep -rl 'cli\.github\.com' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)
  fi

  if [[ -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]]; then
    if df_inst_dry; then
      df_inst_log "would remove /etc/apt/keyrings/githubcli-archive-keyring.gpg"
    else
      df_run_privileged rm -f /etc/apt/keyrings/githubcli-archive-keyring.gpg
    fi
  fi
}

df_inst_run_uninstall() {
  local component="$1"
  local fn="$2"

  df_inst_confirm "$component"
  case "$component" in
    deps | neovim | gh | btop | fzf | lazygit | tldr | starship | bat | fd | eza | zoxide | fetch | tools)
      if ! df_inst_dry; then
        df_ensure_sudo
      fi
      ;;
  esac
  "$fn"
  df_inst_forget_component "$component"
  df_inst_log "$component uninstall complete"
}
