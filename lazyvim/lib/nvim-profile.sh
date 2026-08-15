#!/usr/bin/env bash
# Neovim profile: lazyvim, lazyvim-lite, or none (plain nvim; no profile file).
set -euo pipefail

nvim_profile_file() {
  printf '%s/dotfiles/nvim-profile' "${XDG_DATA_HOME:-$HOME/.local/share}"
}

get_nvim_profile() {
  local file profile
  file="$(nvim_profile_file)"
  if [[ ! -f "$file" ]]; then
    echo "none"
    return 0
  fi
  profile="$(tr -d '[:space:]' <"$file")"
  case "$profile" in
    lazyvim | lazyvim-lite) printf '%s\n' "$profile" ;;
    minimal)
      # Legacy profile from older dotfiles; plain nvim uses no profile file.
      rm -f "$file"
      echo "none"
      ;;
    *)
      echo "none"
      ;;
  esac
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
}

clear_nvim_profile() {
  local file
  file="$(nvim_profile_file)"
  if [[ -f "$file" ]]; then
    rm -f "$file"
  fi
}
