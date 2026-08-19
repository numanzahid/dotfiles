#!/usr/bin/env bash
# Neovim profile: lazyvim, lazyvim-lite, or none (plain nvim).
# This file owns LazyVim vs plain nvim config linking.
set -euo pipefail

_NVIM_PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$_NVIM_PROFILE_DIR/../.." && pwd)}"

# shellcheck source=../../scripts/lib/link.sh
source "$DOTFILES_DIR/scripts/lib/link.sh"

if ! declare -F log >/dev/null 2>&1; then
  log() { printf '%s\n' "$*"; }
fi
if ! declare -F run >/dev/null 2>&1; then
  run() {
    if [[ "${DRY_RUN:-0}" -eq 1 ]]; then
      printf '+'
      printf ' %q' "$@"
      printf '\n'
    else
      "$@"
    fi
  }
fi

nvim_profile_file() {
  printf '%s/dotfiles/nvim-profile' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

nvim_plain_config_dir() {
  printf '%s/home/.config/nvim-plain' "$DOTFILES_DIR"
}

nvim_lazyvim_config_dir() {
  printf '%s/home/.config/nvim' "$DOTFILES_DIR"
}

nvim_home_config_dir() {
  printf '%s/nvim' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

nvim_config_is_lazyvim() {
  local dest src
  dest="$(nvim_home_config_dir)"
  src="$(nvim_lazyvim_config_dir)"
  [[ -e "$dest" || -L "$dest" ]] && df_paths_same "$dest" "$src"
}

link_nvim_plain_config() {
  df_link_path "$(nvim_plain_config_dir)" "$(nvim_home_config_dir)"
}

link_nvim_lazyvim_config() {
  df_link_path "$(nvim_lazyvim_config_dir)" "$(nvim_home_config_dir)"
}

read_nvim_profile_value() {
  local file profile
  file="$(nvim_profile_file)"
  if [[ ! -f "$file" ]]; then
    return 1
  fi
  profile="$(tr -d '[:space:]' <"$file")"
  [[ -n "$profile" ]] || return 1
  printf '%s\n' "$profile"
}

migrate_legacy_nvim_profile() {
  local file profile
  file="$(nvim_profile_file)"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  profile="$(tr -d '[:space:]' <"$file")"
  if [[ "$profile" == "minimal" ]]; then
    rm -f "$file"
  fi
}

get_nvim_profile() {
  local profile
  migrate_legacy_nvim_profile
  if profile="$(read_nvim_profile_value)"; then
    case "$profile" in
      lazyvim | lazyvim-lite) printf '%s\n' "$profile" ;;
      *) echo "none" ;;
    esac
    return 0
  fi
  echo "none"
}

set_nvim_profile() {
  local profile="$1"
  local file
  case "$profile" in
    lazyvim | lazyvim-lite) ;;
    *)
      printf 'nvim-profile: invalid profile: %s (use lazyvim or lazyvim-lite)\n' "$profile" >&2
      return 1
      ;;
  esac
  file="$(nvim_profile_file)"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$profile" >"$file"
  link_nvim_lazyvim_config
}

clear_nvim_profile() {
  local file
  file="$(nvim_profile_file)"
  if [[ -f "$file" ]]; then
    rm -f "$file"
  fi
  link_nvim_plain_config
}
